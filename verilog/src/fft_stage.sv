module fft_stage(
    clk,
    rst,

    fft_stage_ready_in,
    fft_stage_valid_in,
    fft_stage_data_in,

    fft_stage_ready_out,
    fft_stage_valid_out,
    fft_stage_data_out
);
    import helper_pkg::*;
    import fft_pkg::*;

    parameter DATA_WIDTH    = 12;
    parameter FRACTION      = 24;
    parameter FFT_POINTS    = 8;
    parameter BUTTERFLIES   = 4;
    parameter PIPE_WIDTH    = 4;

    localparam TWIDDLES = FFT_POINTS / 2;
    localparam TWIDDLES_W = clog2(TWIDDLES);
    localparam BUTTERFLIES_W = clog2(BUTTERFLIES);
    localparam FFT_POINTS_W = clog2(FFT_POINTS);
    localparam STAGES = FFT_POINTS_W;
    localparam STAGE_W = clog2(STAGES);
    localparam SUBSTAGES = TWIDDLES / BUTTERFLIES;
    localparam SUBSTAGE_W = (SUBSTAGES == 1) ? 0 : clog2(SUBSTAGES);
    localparam DATA_PIPE_WIDTH = PIPE_WIDTH + 2;
    localparam STAGE_DELAY = DATA_PIPE_WIDTH + 1 + (SUBSTAGES-1) * TWIDDLES;
    localparam STAGE_DELAY_W = clog2(STAGE_DELAY);

    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    // state machine states
    typedef enum { 
        READY,
        RUNNING,
        FLUSH
    } state_t;

    input   logic clk;
    input   logic rst;

    output  logic   fft_stage_ready_in;
    input   logic   fft_stage_valid_in;
    input   complex fft_stage_data_in   [0:FFT_POINTS-1];

    input   logic   fft_stage_ready_out;
    output  logic   fft_stage_valid_out;
    output  complex fft_stage_data_out  [0:FFT_POINTS-1];

    state_t state, next_state;
    
    // butterfly input interface
    complex                 butterfly_a_in      [0:BUTTERFLIES-1];
    complex                 butterfly_b_in      [0:BUTTERFLIES-1];
    complex                 butterfly_tw        [0:BUTTERFLIES-1];

    // butterfly output interface
    complex                 butterfly_a_out     [0:BUTTERFLIES-1];
    complex                 butterfly_b_out     [0:BUTTERFLIES-1];

    complex                 butterfly_data_in   [0:FFT_POINTS-1];
    complex                 butterfly_data_out  [0:FFT_POINTS-1];

    logic [FFT_POINTS_W-1:0]    reversed_bits   [0:FFT_POINTS-1];
    logic [FFT_POINTS_W-1:0]    stage_indices   [0:FFT_POINTS-1];

    logic [TWIDDLES_W-1:0]      index_twiddle   [0:BUTTERFLIES-1];
    logic [FFT_POINTS_W-1:0]    index_a         [0:BUTTERFLIES-1];
    logic [FFT_POINTS_W-1:0]    index_b         [0:BUTTERFLIES-1];
    logic [FFT_POINTS_W-1:0]    index_a_pipe    [0:BUTTERFLIES-1][0:DATA_PIPE_WIDTH-1];
    logic [FFT_POINTS_W-1:0]    index_b_pipe    [0:BUTTERFLIES-1][0:DATA_PIPE_WIDTH-1];

    logic [STAGE_W-1:0]     stage;
    logic                   next_stage;
    logic                   reset_stage;

    logic [SUBSTAGE_W-1:0]  substage;

    logic [STAGE_DELAY_W-1:0]   stage_counter;

 // TEMPORARY TWIDDLES //////////////////////////////////////////////////////////

    complex twiddles [0:TWIDDLES-1];

    /*
        0800, 0000
        05a8, fa58
        0000, f800
        fa58, fa58
    */

    generate
        if (FFT_POINTS == 8) begin
            assign twiddles[0].re = 16'h0800;
            assign twiddles[0].im = 16'h0000;
            assign twiddles[1].re = 16'h05a8;
            assign twiddles[1].im = 16'hfa58;
            assign twiddles[2].re = 16'h0000;
            assign twiddles[2].im = 16'hf800;
            assign twiddles[3].re = 16'hfa58;
            assign twiddles[3].im = 16'hfa58;
        end else if (FFT_POINTS == 16) begin

        end else if (FFT_POINTS == 32) begin

        end else if (FFT_POINTS == 64) begin
            assign twiddles[0].re = 16'h0800;
            assign twiddles[0].im = 16'h0000;
            assign twiddles[1].re = 16'h07f6;
            assign twiddles[1].im = 16'hff37;
            assign twiddles[2].re = 16'h07d9;
            assign twiddles[2].im = 16'hfe70;
            assign twiddles[3].re = 16'h07a8;
            assign twiddles[3].im = 16'hfdad;
            assign twiddles[4].re = 16'h0764;
            assign twiddles[4].im = 16'hfcf0;
            assign twiddles[5].re = 16'h070e;
            assign twiddles[5].im = 16'hfc3b;
            assign twiddles[6].re = 16'h06a7;
            assign twiddles[6].im = 16'hfb8e;
            assign twiddles[7].re = 16'h062f;
            assign twiddles[7].im = 16'hfaed;
            assign twiddles[8].re = 16'h05a8;
            assign twiddles[8].im = 16'hfa58;
            assign twiddles[9].re = 16'h0513;
            assign twiddles[9].im = 16'hf9d1;
            assign twiddles[10].re = 16'h0472;
            assign twiddles[10].im = 16'hf959;
            assign twiddles[11].re = 16'h03c5;
            assign twiddles[11].im = 16'hf8f2;
            assign twiddles[12].re = 16'h0310;
            assign twiddles[12].im = 16'hf89c;
            assign twiddles[13].re = 16'h0253;
            assign twiddles[13].im = 16'hf858;
            assign twiddles[14].re = 16'h0190;
            assign twiddles[14].im = 16'hf827;
            assign twiddles[15].re = 16'h00c9;
            assign twiddles[15].im = 16'hf80a;
            assign twiddles[16].re = 16'h0000;
            assign twiddles[16].im = 16'hf800;
            assign twiddles[17].re = 16'hff37;
            assign twiddles[17].im = 16'hf80a;
            assign twiddles[18].re = 16'hfe70;
            assign twiddles[18].im = 16'hf827;
            assign twiddles[19].re = 16'hfdad;
            assign twiddles[19].im = 16'hf858;
            assign twiddles[20].re = 16'hfcf0;
            assign twiddles[20].im = 16'hf89c;
            assign twiddles[21].re = 16'hfc3b;
            assign twiddles[21].im = 16'hf8f2;
            assign twiddles[22].re = 16'hfb8e;
            assign twiddles[22].im = 16'hf959;
            assign twiddles[23].re = 16'hfaed;
            assign twiddles[23].im = 16'hf9d1;
            assign twiddles[24].re = 16'hfa58;
            assign twiddles[24].im = 16'hfa58;
            assign twiddles[25].re = 16'hf9d1;
            assign twiddles[25].im = 16'hfaed;
            assign twiddles[26].re = 16'hf959;
            assign twiddles[26].im = 16'hfb8e;
            assign twiddles[27].re = 16'hf8f2;
            assign twiddles[27].im = 16'hfc3b;
            assign twiddles[28].re = 16'hf89c;
            assign twiddles[28].im = 16'hfcf0;
            assign twiddles[29].re = 16'hf858;
            assign twiddles[29].im = 16'hfdad;
            assign twiddles[30].re = 16'hf827;
            assign twiddles[30].im = 16'hfe70;
            assign twiddles[31].re = 16'hf80a;
            assign twiddles[31].im = 16'hff37;
        end 
    endgenerate



////////////////////////////////////////////////////////////////////////////////
    

    assign fft_stage_ready_in = (state == READY);

    // clock in next_state
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= READY;
        end else begin
            state <= next_state;
        end
    end 

    // determine next_state
    always_comb begin
        next_state = state;
        case (state)
            READY: begin 
                if (fft_stage_valid_in) begin
                    next_state = RUNNING;
                end
            end
            RUNNING: begin
                if (reset_stage) begin
                    next_state = FLUSH;
                end
            end 
            FLUSH: begin
                if (fft_stage_ready_out) begin
                    next_state = READY;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            stage <= {STAGE_W{1'b0}} + 1'b1; 
            next_stage <= 1'b0;
            fft_stage_valid_out <= 1'b0;
            stage_counter <= 'b0;
            reset_stage <= 1'b0;
        end else begin
            

            case (state)
                READY: begin
                    if (fft_stage_valid_in) begin
                        butterfly_data_in <= fft_stage_data_in;
                    end
                end
                RUNNING: begin
                    if (stage_counter == (STAGE_DELAY-1)) begin
                        reset_stage <= (stage == (STAGES - 1));
                        stage_counter <= 'b0;
                        next_stage <= 1'b1;
                    end else if (!next_stage) begin
                        stage_counter <= stage_counter + 1'b1;
                    end

                    if (next_stage) begin
                        stage <= stage + 1'b1;

                        if (reset_stage) begin
                            stage               <= {STAGE_W{1'b0}} + 1'b1;
                            reset_stage         <= 1'b0;
                            fft_stage_valid_out <= 1'b1;
                            fft_stage_data_out  <= butterfly_data_out; 
                        end else begin
                            butterfly_data_in   <= butterfly_data_out;
                        end
                
                        next_stage <= 1'b0;
                    end 
                end
                FLUSH: begin
                    if (fft_stage_ready_out) begin
                        fft_stage_valid_out <= 1'b0;
                    end                    
                end
            endcase 
        end
    end

    // if there are more than one substages
    generate
        if (SUBSTAGES > 1) begin
            assign substage = stage_counter[0+:SUBSTAGE_W];
        end else begin
            assign substage = 1'b0;
        end    
    endgenerate 
    
    generate
        genvar butterfly_no, index;

        for (butterfly_no=0; butterfly_no<BUTTERFLIES; butterfly_no++) begin: butterflies
            butterfly #(
                .DATA_WIDTH         (DATA_WIDTH),
                .FRACTION           (FRACTION),
                .PIPE_WIDTH         (PIPE_WIDTH)
            ) butterfly (
                .clk                (clk),
                .rst                (rst),

                .clken              ((state == RUNNING)),

                .butterfly_a_in     (butterfly_a_in [butterfly_no]),
                .butterfly_b_in     (butterfly_b_in [butterfly_no]),
                .butterfly_tw       (butterfly_tw   [butterfly_no]),

                .butterfly_a_out    (butterfly_a_out[butterfly_no]),
                .butterfly_b_out    (butterfly_b_out[butterfly_no]) 
            );        

            // TODO check all this later, pray it works now
            assign index_twiddle    [butterfly_no] = ((butterfly_no << SUBSTAGE_W) + substage) << (TWIDDLES_W-stage);
            assign index_a          [butterfly_no] = stage_indices[((butterfly_no << SUBSTAGE_W) + substage) << 1];
            assign index_b          [butterfly_no] = stage_indices[(((butterfly_no << SUBSTAGE_W) + substage) << 1) + 1];

            assign butterfly_a_in   [butterfly_no] = butterfly_data_in[index_a[butterfly_no]];
            assign butterfly_b_in   [butterfly_no] = butterfly_data_in[index_b[butterfly_no]];
            assign butterfly_tw     [butterfly_no] = twiddles[index_twiddle[butterfly_no]]; 

            always_ff @(posedge clk) begin
                if (state == RUNNING) begin
                    if (stage == STAGES-1) begin
                        index_a_pipe[butterfly_no] <= {(((butterfly_no << SUBSTAGE_W) + substage)), index_a_pipe[butterfly_no][0:DATA_PIPE_WIDTH-2]};
                        index_b_pipe[butterfly_no] <= {(((butterfly_no << SUBSTAGE_W) + substage) + TWIDDLES), index_b_pipe[butterfly_no][0:DATA_PIPE_WIDTH-2]};
                    end else begin
                        index_a_pipe[butterfly_no] <= {index_a[butterfly_no], index_a_pipe[butterfly_no][0:DATA_PIPE_WIDTH-2]};
                        index_b_pipe[butterfly_no] <= {index_b[butterfly_no], index_b_pipe[butterfly_no][0:DATA_PIPE_WIDTH-2]};
                    end

                    butterfly_data_out[index_a_pipe[butterfly_no][DATA_PIPE_WIDTH-1]] <= butterfly_a_out[butterfly_no];
                    butterfly_data_out[index_b_pipe[butterfly_no][DATA_PIPE_WIDTH-1]] <= butterfly_b_out[butterfly_no];
                end
            end
        end

        for (index=0; index<FFT_POINTS; index++) begin: set_stage_indices
            assign reversed_bits[index] = reversebits(index)[31-:FFT_POINTS_W];

            always_ff @(posedge clk) begin
                if (rst) begin
                    /* flip the top two bits and register the rest normally
                    this will break at FFT_POINTS < 8 */
                    stage_indices[index][FFT_POINTS_W-1]    <= reversed_bits[index][FFT_POINTS_W-2]; 
                    stage_indices[index][FFT_POINTS_W-2]    <= reversed_bits[index][FFT_POINTS_W-1];
                    stage_indices[index][FFT_POINTS_W-3:0]  <= reversed_bits[index][FFT_POINTS_W-3:0];
                end else begin
                    if (reset_stage) begin
                        /* flip the top two bits and register the rest normally
                        this will break at FFT_POINTS < 8 */
                        stage_indices[index][FFT_POINTS_W-1]    <= reversed_bits[index][FFT_POINTS_W-2]; 
                        stage_indices[index][FFT_POINTS_W-2]    <= reversed_bits[index][FFT_POINTS_W-1];
                        stage_indices[index][FFT_POINTS_W-3:0]  <= reversed_bits[index][FFT_POINTS_W-3:0];
                    end else if (next_stage) begin
                        stage_indices[index][FFT_POINTS_W-1-stage-:2] <= {stage_indices[index][FFT_POINTS_W-2-stage], stage_indices[index][FFT_POINTS_W-1-stage]};
                    end
                end
            end 
        end
    endgenerate




endmodule