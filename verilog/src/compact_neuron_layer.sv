module compact_neuron_layer (
    clk,
    rst,

    compact_neuron_layer_ready_in,
    compact_neuron_layer_valid_in,
    compact_neuron_layer_data_in,

    compact_neuron_layer_ready_out,
    compact_neuron_layer_valid_out,
    compact_neuron_layer_data_out
);
    import helper_pkg::*;

    parameter DATA_WIDTH        = 16;
    parameter PARAMS_INIT_FILE  = "";
    parameter NUM_NEURONS       = 32;
    parameter NEURON_INPUTS     = 32;
    parameter PIPE_WIDTH        = 4;
    // position of the decimal point from the right
    parameter FRACTION          = 24;  

    localparam FRACTIONAL_BITS = FRACTION;
    localparam INTEGER_BITS = (DATA_WIDTH-FRACTION);
    /* FRACTION Example

        localparam DATA_WIDTH = 12;
        localparam FRACTION = 9;

        some_data = 12'b001000000000 = 0b001.000000000 = 0d1.0

    */
    
    // capture the entire possible width of a multiplier output (no truncation)
    localparam LPM_OUT_WIDTH = DATA_WIDTH * 2; 

    // where the MSB will be when computing a multiplication
    // from the MSB -: DATA_WIDTH to correctly truncate the data
    localparam LPM_OUT_MSB = (LPM_OUT_WIDTH - 1) - (DATA_WIDTH - FRACTION); 

    // column width in bits 
    localparam RAM_WIDTH = DATA_WIDTH + (DATA_WIDTH * NEURON_INPUTS);
    // row depth (number of rows)
    localparam RAM_DEPTH = NUM_NEURONS; // weight RAM row depth

    // width in bits of the RAM address buses
    localparam RAM_ADDRESS_WIDTH = clog2(RAM_DEPTH); 
    localparam RAM_ACCESS_DELAY = 3;
    localparam DELAY_COUNTER_WIDTH = clog2(RAM_ACCESS_DELAY);

    // state machine states
    typedef enum { 
        READY,
        LOAD_PARAMS,
        FIRE_NEURON,
        FLUSH
    } state_t;

    input logic clk;
    input logic rst;

    output logic                        compact_neuron_layer_ready_in;
    input logic                         compact_neuron_layer_valid_in;
    input logic     [DATA_WIDTH-1:0]    compact_neuron_layer_data_in    [0:NEURON_INPUTS-1];

    input logic                         compact_neuron_layer_ready_out;
    output logic                        compact_neuron_layer_valid_out;
    output logic    [DATA_WIDTH-1:0]    compact_neuron_layer_data_out   [0:NUM_NEURONS-1];

    state_t state, next_state;

    logic [RAM_ADDRESS_WIDTH-1:0] neuron_ram_address;
    logic [RAM_WIDTH-1:0]           neuron_ram_out;

    logic                   neuron_ready_in;
    logic                   neuron_valid_in;
    logic [DATA_WIDTH-1:0]  neuron_data_in  [0:NEURON_INPUTS-1];

    logic [DATA_WIDTH-1:0]  neuron_weights  [0:NEURON_INPUTS-1];
    logic [DATA_WIDTH-1:0]  neuron_bias;

    logic                   neuron_ready_out;
    logic                   neuron_valid_out;
    logic [DATA_WIDTH-1:0]  neuron_data_out;

    logic all_fired;

    logic [DELAY_COUNTER_WIDTH-1:0] delay_counter;
    logic params_loaded;

    assign compact_neuron_layer_ready_in = (state == READY);

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= READY;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state) 
            READY: begin
                if (compact_neuron_layer_valid_in) begin
                    next_state = LOAD_PARAMS;
                end
            end
            LOAD_PARAMS: begin
                if (params_loaded) begin
                    next_state = FIRE_NEURON;
                end
            end
            FIRE_NEURON: begin
                if (neuron_valid_out) begin
                    if (all_fired) begin
                        next_state = FLUSH;
                    end else begin
                        next_state = LOAD_PARAMS;
                    end
                end
            end
            FLUSH: begin
                if (compact_neuron_layer_ready_out) begin
                    next_state = READY;
                end
            end
        endcase
    end

    assign neuron_ready_out = (state == FIRE_NEURON);

    always_ff @(posedge clk) begin
        if (rst) begin
            neuron_ram_address <= {RAM_ADDRESS_WIDTH{1'b0}};
            delay_counter <= {DELAY_COUNTER_WIDTH{1'b0}};
            neuron_valid_in <= 1'b0;
            params_loaded <= 1'b0;
            compact_neuron_layer_valid_out <= 1'b0;
            all_fired <= 1'b0;
        end else begin
            case (state) 
                READY: begin
                    if (compact_neuron_layer_valid_in) begin
                        neuron_data_in <= compact_neuron_layer_data_in;
                    end
                end
                LOAD_PARAMS: begin
                    delay_counter <= delay_counter + 1'b1;
                    if (delay_counter == RAM_ACCESS_DELAY-2) begin
                        params_loaded <= 1'b1;
                    end
                    if (params_loaded) begin
                        neuron_valid_in <= 1'b1;
                        params_loaded <= 1'b0;
                    end
                    
                end
                FIRE_NEURON: begin
                    if (neuron_ready_in) begin
                        neuron_valid_in <= 1'b0;
                    end

                    if (neuron_valid_out) begin 

                        if (neuron_ram_address == NUM_NEURONS-2) begin
                            all_fired <= 1'b1;
                        end
                        if (all_fired) begin
                            compact_neuron_layer_valid_out <= 1'b1;
                        end
                        neuron_ram_address <= neuron_ram_address + 1'b1;
                        compact_neuron_layer_data_out[neuron_ram_address] <= neuron_data_out;
                    end
                end
                FLUSH: begin
                    if (compact_neuron_layer_ready_out) begin
                        all_fired <= 1'b0;
                        neuron_ram_address <= {RAM_ADDRESS_WIDTH{1'b0}};
                        params_loaded <= 1'b0;
                        delay_counter <= {DELAY_COUNTER_WIDTH{1'b0}};

                        compact_neuron_layer_valid_out <= 1'b0;
                    end
                end
            endcase
        end
    end

    generate
        genvar nrn_input;
        for (nrn_input=0; nrn_input<NEURON_INPUTS; nrn_input++) begin: PARAM_SLICER
            always_ff @(posedge clk) begin
                if (rst) begin
                    neuron_weights[nrn_input] <= {DATA_WIDTH{1'b0}};
                end else begin
                    if (state == LOAD_PARAMS) begin
                        neuron_weights[(NEURON_INPUTS-1)-nrn_input] <= neuron_ram_out[nrn_input*DATA_WIDTH+:DATA_WIDTH];
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            neuron_bias <= {DATA_WIDTH{1'b0}};
        end else begin
            if (state == LOAD_PARAMS) begin
                neuron_bias <= neuron_ram_out[(RAM_WIDTH-1)-:DATA_WIDTH];
            end
        end
    end 

    // weights RAM
    sp_ram #(
        .WIDTH          (RAM_WIDTH),
        .DEPTH          (RAM_DEPTH),
        .INIT_FILE      (PARAMS_INIT_FILE),
        .ADDRESS_WIDTH  (RAM_ADDRESS_WIDTH)
    ) neuron_ram (
        .address    (neuron_ram_address),
        .clock      (clk),
        .data       (), // unconnected (for now)
        .rden       (1'b1), // tied high (for now) 
        .wren       (1'b0), // tied low (for now)
        .q          (neuron_ram_out)
    );


    neuron #(
        .DATA_WIDTH         (DATA_WIDTH),
        .NUM_INPUTS         (NEURON_INPUTS),
        .PIPE_WIDTH         (PIPE_WIDTH),
        .FRACTION           (FRACTION)
    ) neuron (
        .clk                (clk),
        .rst                (rst),

        .neuron_ready_in    (neuron_ready_in),
        .neuron_valid_in    (neuron_valid_in),
        .neuron_data_in     (neuron_data_in),

        .neuron_weights     (neuron_weights),
        .neuron_bias        (neuron_bias),

        .neuron_ready_out   (neuron_ready_out),
        .neuron_valid_out   (neuron_valid_out),
        .neuron_data_out    (neuron_data_out)
    );

endmodule