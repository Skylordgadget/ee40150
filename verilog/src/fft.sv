module fft(
    clk,
    rst,

    fft_ready_in,
    fft_valid_in,
    fft_data_in,

    fft_ready_out,
    fft_valid_out,
    fft_data_out
);
    import helper_pkg::*;
    import fft_pkg::*;

    parameter DATA_WIDTH = 12;
    parameter FRACTION  = 24; 
    parameter FFT_POINTS = 64; // always a power of 2
    parameter BUTTERFLIES = 4; // always a power of 2 shouldn't be more than FFT_POINTS / 2
    parameter PIPE_WIDTH = 4;

    localparam BUTTERFLIES_W = clog2(BUTTERFLIES);
    localparam STAGES = clog2(FFT_POINTS);
    localparam STAGE_W = clog2(STAGES);
    localparam NUM_TWIDDLES = FFT_POINTS / 2; 
    localparam SUBSTAGES = NUM_TWIDDLES / BUTTERFLIES;
    localparam NUM_TWIDDLES_W = clog2(NUM_TWIDDLES);
    localparam SUBSTAGE_W = clog2(SUBSTAGES);

    typedef enum { STARTUP, RUNNING, DONE } state_t;

    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    /* testing, remove this later =========================================== */

    input logic clk;
    input logic rst;
    
    output logic fft_ready_in;
    input logic fft_valid_in;
    input logic [DATA_WIDTH-1:0] fft_data_in;

    input logic fft_ready_out;
    output logic fft_valid_out;
    output complex fft_data_out [0:FFT_POINTS-1];

    state_t state, next_state;

    logic next_stage, reset_stage; 
    logic [STAGE_W-1:0] stage;
    logic next_substage, reset_substage;
    logic [SUBSTAGE_W-1:0] substage;
    logic [BUTTERFLIES_W-1:0] stage_ready;

    logic butterfly_ready_out;
    logic [BUTTERFLIES-1:0] butterfly_valid_out;

    logic [NUM_TWIDDLES_W-1:0] index_twiddle [0:BUTTERFLIES-1];

    logic [STAGES-1:0] indices [0:FFT_POINTS-1];
    logic [STAGES-1:0] index_a [0:BUTTERFLIES-1];
    logic [STAGES-1:0] index_b [0:BUTTERFLIES-1];

    logic stage_valid_in;
    logic [STAGES-1:0] startup_counter;

    complex twiddle8 [0:NUM_TWIDDLES-1]; // complex number
    logic stage_valid_out;
    complex butterfly_data_in [0:FFT_POINTS-1];
    complex butterfly_a_out [0:BUTTERFLIES-1];
    complex butterfly_b_out [0:BUTTERFLIES-1];
    complex butterfly_data_out [0:FFT_POINTS-1];

    complex startup_reg [0:FFT_POINTS-1];
    complex stage1 [0:FFT_POINTS-1];
    complex stage2 [0:FFT_POINTS-1];
    complex stage3 [0:FFT_POINTS-1];
    /*
        0800, 0000
        05a8, fa58
        0000, f800
        fa58, fa58
    */

    assign twiddle8[0].re = 16'h0800;
    assign twiddle8[0].im = 16'h0000;

    assign twiddle8[1].re = 16'h05a8;
    assign twiddle8[1].im = 16'hfa58;

    assign twiddle8[2].re = 16'h0000;
    assign twiddle8[2].im = 16'hf800;

    assign twiddle8[3].re = 16'hfa58;
    assign twiddle8[3].im = 16'hfa58;

    /* ====================================================================== */
    
    assign fft_ready_in = &stage_ready;

    // generate as many butterfly blocks as the user wants

    always_ff @(posedge clk) begin
        if (rst) begin
            stage_valid_out <= 1'b0;
        end else begin
            stage_valid_out <= &butterfly_valid_out;
        end 
    end

    generate
        genvar butterfly_no, index;
        for (butterfly_no=0; butterfly_no<BUTTERFLIES; butterfly_no++) begin

            always_ff @(posedge clk) begin
                if (rst) begin
                    butterfly_data_out[butterfly_no] <= 'b0;
                    
                end else begin
                    butterfly_data_out[index_a[butterfly_no]] <= butterfly_a_out[butterfly_no];
                    butterfly_data_out[index_b[butterfly_no]] <= butterfly_b_out[butterfly_no];
                end
            end

            butterfly #(
                .DATA_WIDTH (DATA_WIDTH),
                .FRACTION   (FRACTION),
                .PIPE_WIDTH (PIPE_WIDTH)
            ) butterfly (
                .clk        (clk),
                .rst        (rst),

                .butterfly_ready_in (stage_ready[butterfly_no]),
                .butterfly_valid_in (stage_valid_in), // TODO
                .butterfly_a_in     (butterfly_data_in[index_a[butterfly_no]]), // TODO
                .butterfly_b_in     (butterfly_data_in[index_b[butterfly_no]]), // TODO
                .butterfly_tw       (twiddle8[index_twiddle[butterfly_no]]), // TODO

                .butterfly_ready_out(butterfly_ready_out),
                .butterfly_valid_out(butterfly_valid_out[butterfly_no]), // TODO
                .butterfly_a_out    (butterfly_a_out[butterfly_no]), // TODO
                .butterfly_b_out    (butterfly_b_out[butterfly_no]) // TODO
            );


            for (index=0; index<FFT_POINTS; index++) begin
                always_ff @(posedge clk) begin
                    if (rst) begin
                        indices[index] <= reversebits(index)[31-:STAGES];
                    end else begin
                        if (reset_stage && reset_substage) begin
                            indices[index] <= reversebits(index)[31-:STAGES];
                        end else if (next_stage) begin
                            indices[index][STAGES-1-stage-:2] <= {indices[index][STAGES-2-stage], indices[index][STAGES-1-stage]};
                        end    
                    end
                end
            end

            always_comb begin
                index_twiddle[butterfly_no] = ((butterfly_no << 1) + substage) << (NUM_TWIDDLES_W-stage);
                index_a[butterfly_no] = indices[((butterfly_no << 1) + substage) << 1];
                index_b[butterfly_no] = indices[(((butterfly_no << 1) + substage) << 1) + 1];
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            stage <= {STAGE_W{1'b0}};
            next_stage <= 1'b0;
            reset_stage <= 1'b0;
            
        end else begin
            fft_valid_out <= 1'b0;
            if (next_stage) begin
                stage <= stage + 1'b1;
                
                if (reset_stage) begin
                    stage <= {STAGE_W{1'b0}};
                    reset_stage <= 1'b0;

                    fft_valid_out <= 1'b1;
                    fft_data_out <= butterfly_data_out; 

                    butterfly_data_in <= startup_reg;
                end else begin
                    butterfly_data_in <= butterfly_data_out;
                end
                
                if (stage >= STAGES-2) begin
                    reset_stage <= 1'b1;
                end 
                
                next_stage <= 1'b0;
            end
        end
    end

    generate
        if (SUBSTAGES > 1) begin
            always_ff @(posedge clk) begin
                if (rst) begin
                    substage <= {SUBSTAGE_W{1'b0}};
                    reset_substage <= 1'b0;
                    next_substage <= 1'b0;
                end else begin
                    

                    if (next_substage) begin
                        substage <= substage + 1'b1;
                        if (reset_substage) begin
                            substage <= {SUBSTAGE_W{1'b0}};
                            reset_substage <= 1'b0;
                        end else if (substage >= SUBSTAGES-2) begin
                            reset_substage <= 1'b1;
                            next_stage <= 1'b1;
                        end
                    end else begin
                        next_substage <= &butterfly_valid_out;
                    end
                end
            end
        end else begin
            assign substage = 1'b0;
        end
    endgenerate


    always_ff @(posedge clk) begin
        if (rst) begin
            state <= STARTUP;
        end else begin
            if (fft_ready_in) begin
                state <= next_state;
            end
        end
    end

    always_comb begin
        next_state = state;

        case (state)
            STARTUP: begin
                if (stage_valid_in) begin
                    next_state = RUNNING;
                end
            end
            RUNNING: begin
                if (reset_stage) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = stage_valid_in ? RUNNING : STARTUP;
            end
            default: begin
                next_state = STARTUP;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            startup_counter <= {STAGES{1'b0}};
            stage_valid_in <= 1'b0;
        end else begin
            if (fft_valid_in && fft_ready_out) begin
                if (~stage_valid_in | (state == DONE)) begin
                    startup_counter <= startup_counter + 1'b1;
                    startup_reg <= {{fft_data_in,{DATA_WIDTH{1'b0}}}, startup_reg[0:FFT_POINTS-2]};
                    stage_valid_in <= (startup_counter==FFT_POINTS-1);
                end

                if (state == STARTUP) begin
                    butterfly_data_in <= startup_reg;
                end
            end
        end
    end


    assign butterfly_ready_out = rst ? 1'b0 : ~fft_valid_out | fft_ready_out;
                                               
endmodule