`timescale 1ns / 1ns

module compact_neuron_layer_tb();
    import helper_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 16;
    localparam PARAMS_INIT_FILE = "../verilog/test/weights/test_params_8I8F.hex";
    localparam NUM_NEURONS = 4;
    localparam NEURON_INPUTS = 4;
    localparam PIPE_WIDTH = 4;
    localparam FRACTION = 8; // position of the decimal point from the right 

    localparam FRACTIONAL_BITS = FRACTION;
    localparam INTEGER_BITS = (DATA_WIDTH-FRACTION);
    // column width in bits 
    localparam RAM_WIDTH = DATA_WIDTH + (DATA_WIDTH * NEURON_INPUTS);
    // row depth (number of rows)
    localparam RAM_DEPTH = NUM_NEURONS; // weight RAM row depth

    // capture the entire possible width of a multiplier output (no truncation)
    localparam LPM_OUT_WIDTH = DATA_WIDTH * 2; 

    // where the MSB will be when computing a multiplication
    // from the MSB -: DATA_WIDTH to correctly truncate the data
    localparam LPM_OUT_MSB = (LPM_OUT_WIDTH - 1) - (DATA_WIDTH - FRACTION); 

    logic clk;
    logic rst;

    logic                   compact_neuron_layer_ready_in;
    logic                   compact_neuron_layer_valid_in;
    logic [DATA_WIDTH-1:0]  compact_neuron_layer_data_in [0:NEURON_INPUTS-1];

    logic                   compact_neuron_layer_ready_out;
    logic                   compact_neuron_layer_valid_out;
    logic [DATA_WIDTH-1:0]  compact_neuron_layer_data_out   [0:NUM_NEURONS-1];

    typedef logic [DATA_WIDTH-1:0] nrn_in_t [NEURON_INPUTS];
    typedef logic [DATA_WIDTH-1:0] nrn_t [NUM_NEURONS];

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    compact_neuron_layer #(
        .DATA_WIDTH         (DATA_WIDTH),
        .PARAMS_INIT_FILE   (PARAMS_INIT_FILE),
        .NUM_NEURONS        (NUM_NEURONS),
        .NEURON_INPUTS      (NEURON_INPUTS),
        .PIPE_WIDTH         (PIPE_WIDTH),
        .FRACTION           (FRACTION)
    ) compact_neuron_layer (
        .clk    (clk),
        .rst    (rst),

        .compact_neuron_layer_ready_in   (compact_neuron_layer_ready_in),
        .compact_neuron_layer_valid_in   (compact_neuron_layer_valid_in),
        .compact_neuron_layer_data_in    (compact_neuron_layer_data_in),

        .compact_neuron_layer_ready_out  (compact_neuron_layer_ready_out),
        .compact_neuron_layer_valid_out  (compact_neuron_layer_valid_out),
        .compact_neuron_layer_data_out   (compact_neuron_layer_data_out)
    );

    int unsigned num_inputs = 1000;

    mailbox mbx = new(num_inputs);

    bit valid;
    bit ready;
    
    int nrn, nrn_in;
    
    bit valid_queue[$];                                                         
    nrn_in_t rand_data_queue[$];      
    nrn_in_t rand_data;
    nrn_t nrn_data;
    logic [LPM_OUT_WIDTH-1:0] temp = 'b0;

    

    initial begin
        for (int i=0; i<num_inputs; i++) begin
            //valid = 1'b1;
            valid = $urandom_range(1'b0, 1'b1);
            for (int j=0; j<NEURON_INPUTS; j++) begin
                rand_data[j] = {$urandom_range(0, 10),{FRACTIONAL_BITS{1'b0}}};
            end



            valid_queue.push_back(valid);
            rand_data_queue.push_back(rand_data);

            if (valid) begin
                
                for (nrn=0; nrn<NUM_NEURONS; nrn++) begin
                    temp = 'b0;
                    for (nrn_in=0; nrn_in<NEURON_INPUTS; nrn_in++) begin
                        temp += rand_data[NEURON_INPUTS-1-nrn_in] * compact_neuron_layer.neuron_ram.altsyncram_component.m_default.altsyncram_inst.mem_data[nrn][nrn_in*DATA_WIDTH+:DATA_WIDTH];
                    end

                    nrn_data[nrn] = temp[LPM_OUT_MSB-:DATA_WIDTH] + compact_neuron_layer.neuron_ram.altsyncram_component.m_default.altsyncram_inst.mem_data[nrn][(RAM_WIDTH-1)-:DATA_WIDTH];
                end
                
                mbx.put(nrn_data);
            end
        end

        compact_neuron_layer_ready_out = 1'b0;
        compact_neuron_layer_valid_in = 1'b0;
        for (int i=0; i<NEURON_INPUTS; i++) begin
            compact_neuron_layer_data_in[i] = 'b0;
        end
        
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);
            
            compact_neuron_layer_ready_out <= $urandom_range(1'b0, 1'b1);
            //compact_neuron_layer_ready_out <= 1'b1;
            if (compact_neuron_layer_ready_in | ~compact_neuron_layer_valid_in) begin
                compact_neuron_layer_valid_in <= valid_queue.pop_front();
                compact_neuron_layer_data_in <= rand_data_queue.pop_front();
            end
        end

        // compact_neuron_layer_data_in <= rand_data_queue.pop_front();
        // for (int i=0; i<num_inputs; i++) begin
        //     #(CLK_PERIOD);
            
        //     // //compact_neuron_layer_ready_out <= $urandom_range(1'b0, 1'b1);
        //     compact_neuron_layer_ready_out <= 1'b1;
        //     // if (compact_neuron_layer_ready_in | ~compact_neuron_layer_valid_in) begin
        //     //     //compact_neuron_layer_valid_in <= valid_queue.pop_front();
        //     compact_neuron_layer_valid_in <= 1'b1;
        //     //     compact_neuron_layer_data_in <= rand_data_queue.pop_front();
        //     // end
        // end

        $display("test successful");
        $stop;
    end

    initial begin
        nrn_t mbx_received;
        int sum;
        forever begin
            #(CLK_PERIOD);
            if (compact_neuron_layer_valid_out && compact_neuron_layer_ready_out) begin
                mbx.get(mbx_received);
                if (mbx_received != compact_neuron_layer_data_out) begin
                    $display("discrepency between expected value: %p, and received value: %p", mbx_received, compact_neuron_layer_data_out);
                    $stop;
                end
            end
        end
    end


endmodule