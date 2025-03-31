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


    complex twiddles [0:TWIDDLES-1];
    
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

    // TWIDDLES ////////////////////////////////////////////////////////////////
    assign twiddles[0].re = 18'h00080;
    assign twiddles[0].im = 18'h00000;
    assign twiddles[1].re = 18'h00080;
    assign twiddles[1].im = 18'h3fffd;
    assign twiddles[2].re = 18'h00080;
    assign twiddles[2].im = 18'h3fffa;
    assign twiddles[3].re = 18'h00080;
    assign twiddles[3].im = 18'h3fff7;
    assign twiddles[4].re = 18'h0007f;
    assign twiddles[4].im = 18'h3fff3;
    assign twiddles[5].re = 18'h0007f;
    assign twiddles[5].im = 18'h3fff0;
    assign twiddles[6].re = 18'h0007f;
    assign twiddles[6].im = 18'h3ffed;
    assign twiddles[7].re = 18'h0007e;
    assign twiddles[7].im = 18'h3ffea;
    assign twiddles[8].re = 18'h0007e;
    assign twiddles[8].im = 18'h3ffe7;
    assign twiddles[9].re = 18'h0007d;
    assign twiddles[9].im = 18'h3ffe4;
    assign twiddles[10].re = 18'h0007c;
    assign twiddles[10].im = 18'h3ffe1;
    assign twiddles[11].re = 18'h0007b;
    assign twiddles[11].im = 18'h3ffde;
    assign twiddles[12].re = 18'h0007a;
    assign twiddles[12].im = 18'h3ffdb;
    assign twiddles[13].re = 18'h0007a;
    assign twiddles[13].im = 18'h3ffd8;
    assign twiddles[14].re = 18'h00079;
    assign twiddles[14].im = 18'h3ffd5;
    assign twiddles[15].re = 18'h00077;
    assign twiddles[15].im = 18'h3ffd2;
    assign twiddles[16].re = 18'h00076;
    assign twiddles[16].im = 18'h3ffcf;
    assign twiddles[17].re = 18'h00075;
    assign twiddles[17].im = 18'h3ffcc;
    assign twiddles[18].re = 18'h00074;
    assign twiddles[18].im = 18'h3ffc9;
    assign twiddles[19].re = 18'h00072;
    assign twiddles[19].im = 18'h3ffc6;
    assign twiddles[20].re = 18'h00071;
    assign twiddles[20].im = 18'h3ffc4;
    assign twiddles[21].re = 18'h0006f;
    assign twiddles[21].im = 18'h3ffc1;
    assign twiddles[22].re = 18'h0006e;
    assign twiddles[22].im = 18'h3ffbe;
    assign twiddles[23].re = 18'h0006c;
    assign twiddles[23].im = 18'h3ffbc;
    assign twiddles[24].re = 18'h0006a;
    assign twiddles[24].im = 18'h3ffb9;
    assign twiddles[25].re = 18'h00069;
    assign twiddles[25].im = 18'h3ffb6;
    assign twiddles[26].re = 18'h00067;
    assign twiddles[26].im = 18'h3ffb4;
    assign twiddles[27].re = 18'h00065;
    assign twiddles[27].im = 18'h3ffb1;
    assign twiddles[28].re = 18'h00063;
    assign twiddles[28].im = 18'h3ffaf;
    assign twiddles[29].re = 18'h00061;
    assign twiddles[29].im = 18'h3ffac;
    assign twiddles[30].re = 18'h0005f;
    assign twiddles[30].im = 18'h3ffaa;
    assign twiddles[31].re = 18'h0005d;
    assign twiddles[31].im = 18'h3ffa8;
    assign twiddles[32].re = 18'h0005b;
    assign twiddles[32].im = 18'h3ffa5;
    assign twiddles[33].re = 18'h00058;
    assign twiddles[33].im = 18'h3ffa3;
    assign twiddles[34].re = 18'h00056;
    assign twiddles[34].im = 18'h3ffa1;
    assign twiddles[35].re = 18'h00054;
    assign twiddles[35].im = 18'h3ff9f;
    assign twiddles[36].re = 18'h00051;
    assign twiddles[36].im = 18'h3ff9d;
    assign twiddles[37].re = 18'h0004f;
    assign twiddles[37].im = 18'h3ff9b;
    assign twiddles[38].re = 18'h0004c;
    assign twiddles[38].im = 18'h3ff99;
    assign twiddles[39].re = 18'h0004a;
    assign twiddles[39].im = 18'h3ff97;
    assign twiddles[40].re = 18'h00047;
    assign twiddles[40].im = 18'h3ff96;
    assign twiddles[41].re = 18'h00044;
    assign twiddles[41].im = 18'h3ff94;
    assign twiddles[42].re = 18'h00042;
    assign twiddles[42].im = 18'h3ff92;
    assign twiddles[43].re = 18'h0003f;
    assign twiddles[43].im = 18'h3ff91;
    assign twiddles[44].re = 18'h0003c;
    assign twiddles[44].im = 18'h3ff8f;
    assign twiddles[45].re = 18'h0003a;
    assign twiddles[45].im = 18'h3ff8e;
    assign twiddles[46].re = 18'h00037;
    assign twiddles[46].im = 18'h3ff8c;
    assign twiddles[47].re = 18'h00034;
    assign twiddles[47].im = 18'h3ff8b;
    assign twiddles[48].re = 18'h00031;
    assign twiddles[48].im = 18'h3ff8a;
    assign twiddles[49].re = 18'h0002e;
    assign twiddles[49].im = 18'h3ff89;
    assign twiddles[50].re = 18'h0002b;
    assign twiddles[50].im = 18'h3ff87;
    assign twiddles[51].re = 18'h00028;
    assign twiddles[51].im = 18'h3ff86;
    assign twiddles[52].re = 18'h00025;
    assign twiddles[52].im = 18'h3ff86;
    assign twiddles[53].re = 18'h00022;
    assign twiddles[53].im = 18'h3ff85;
    assign twiddles[54].re = 18'h0001f;
    assign twiddles[54].im = 18'h3ff84;
    assign twiddles[55].re = 18'h0001c;
    assign twiddles[55].im = 18'h3ff83;
    assign twiddles[56].re = 18'h00019;
    assign twiddles[56].im = 18'h3ff82;
    assign twiddles[57].re = 18'h00016;
    assign twiddles[57].im = 18'h3ff82;
    assign twiddles[58].re = 18'h00013;
    assign twiddles[58].im = 18'h3ff81;
    assign twiddles[59].re = 18'h00010;
    assign twiddles[59].im = 18'h3ff81;
    assign twiddles[60].re = 18'h0000d;
    assign twiddles[60].im = 18'h3ff81;
    assign twiddles[61].re = 18'h00009;
    assign twiddles[61].im = 18'h3ff80;
    assign twiddles[62].re = 18'h00006;
    assign twiddles[62].im = 18'h3ff80;
    assign twiddles[63].re = 18'h00003;
    assign twiddles[63].im = 18'h3ff80;
    assign twiddles[64].re = 18'h00000;
    assign twiddles[64].im = 18'h3ff80;
    assign twiddles[65].re = 18'h3fffd;
    assign twiddles[65].im = 18'h3ff80;
    assign twiddles[66].re = 18'h3fffa;
    assign twiddles[66].im = 18'h3ff80;
    assign twiddles[67].re = 18'h3fff7;
    assign twiddles[67].im = 18'h3ff80;
    assign twiddles[68].re = 18'h3fff3;
    assign twiddles[68].im = 18'h3ff81;
    assign twiddles[69].re = 18'h3fff0;
    assign twiddles[69].im = 18'h3ff81;
    assign twiddles[70].re = 18'h3ffed;
    assign twiddles[70].im = 18'h3ff81;
    assign twiddles[71].re = 18'h3ffea;
    assign twiddles[71].im = 18'h3ff82;
    assign twiddles[72].re = 18'h3ffe7;
    assign twiddles[72].im = 18'h3ff82;
    assign twiddles[73].re = 18'h3ffe4;
    assign twiddles[73].im = 18'h3ff83;
    assign twiddles[74].re = 18'h3ffe1;
    assign twiddles[74].im = 18'h3ff84;
    assign twiddles[75].re = 18'h3ffde;
    assign twiddles[75].im = 18'h3ff85;
    assign twiddles[76].re = 18'h3ffdb;
    assign twiddles[76].im = 18'h3ff86;
    assign twiddles[77].re = 18'h3ffd8;
    assign twiddles[77].im = 18'h3ff86;
    assign twiddles[78].re = 18'h3ffd5;
    assign twiddles[78].im = 18'h3ff87;
    assign twiddles[79].re = 18'h3ffd2;
    assign twiddles[79].im = 18'h3ff89;
    assign twiddles[80].re = 18'h3ffcf;
    assign twiddles[80].im = 18'h3ff8a;
    assign twiddles[81].re = 18'h3ffcc;
    assign twiddles[81].im = 18'h3ff8b;
    assign twiddles[82].re = 18'h3ffc9;
    assign twiddles[82].im = 18'h3ff8c;
    assign twiddles[83].re = 18'h3ffc6;
    assign twiddles[83].im = 18'h3ff8e;
    assign twiddles[84].re = 18'h3ffc4;
    assign twiddles[84].im = 18'h3ff8f;
    assign twiddles[85].re = 18'h3ffc1;
    assign twiddles[85].im = 18'h3ff91;
    assign twiddles[86].re = 18'h3ffbe;
    assign twiddles[86].im = 18'h3ff92;
    assign twiddles[87].re = 18'h3ffbc;
    assign twiddles[87].im = 18'h3ff94;
    assign twiddles[88].re = 18'h3ffb9;
    assign twiddles[88].im = 18'h3ff96;
    assign twiddles[89].re = 18'h3ffb6;
    assign twiddles[89].im = 18'h3ff97;
    assign twiddles[90].re = 18'h3ffb4;
    assign twiddles[90].im = 18'h3ff99;
    assign twiddles[91].re = 18'h3ffb1;
    assign twiddles[91].im = 18'h3ff9b;
    assign twiddles[92].re = 18'h3ffaf;
    assign twiddles[92].im = 18'h3ff9d;
    assign twiddles[93].re = 18'h3ffac;
    assign twiddles[93].im = 18'h3ff9f;
    assign twiddles[94].re = 18'h3ffaa;
    assign twiddles[94].im = 18'h3ffa1;
    assign twiddles[95].re = 18'h3ffa8;
    assign twiddles[95].im = 18'h3ffa3;
    assign twiddles[96].re = 18'h3ffa5;
    assign twiddles[96].im = 18'h3ffa5;
    assign twiddles[97].re = 18'h3ffa3;
    assign twiddles[97].im = 18'h3ffa8;
    assign twiddles[98].re = 18'h3ffa1;
    assign twiddles[98].im = 18'h3ffaa;
    assign twiddles[99].re = 18'h3ff9f;
    assign twiddles[99].im = 18'h3ffac;
    assign twiddles[100].re = 18'h3ff9d;
    assign twiddles[100].im = 18'h3ffaf;
    assign twiddles[101].re = 18'h3ff9b;
    assign twiddles[101].im = 18'h3ffb1;
    assign twiddles[102].re = 18'h3ff99;
    assign twiddles[102].im = 18'h3ffb4;
    assign twiddles[103].re = 18'h3ff97;
    assign twiddles[103].im = 18'h3ffb6;
    assign twiddles[104].re = 18'h3ff96;
    assign twiddles[104].im = 18'h3ffb9;
    assign twiddles[105].re = 18'h3ff94;
    assign twiddles[105].im = 18'h3ffbc;
    assign twiddles[106].re = 18'h3ff92;
    assign twiddles[106].im = 18'h3ffbe;
    assign twiddles[107].re = 18'h3ff91;
    assign twiddles[107].im = 18'h3ffc1;
    assign twiddles[108].re = 18'h3ff8f;
    assign twiddles[108].im = 18'h3ffc4;
    assign twiddles[109].re = 18'h3ff8e;
    assign twiddles[109].im = 18'h3ffc6;
    assign twiddles[110].re = 18'h3ff8c;
    assign twiddles[110].im = 18'h3ffc9;
    assign twiddles[111].re = 18'h3ff8b;
    assign twiddles[111].im = 18'h3ffcc;
    assign twiddles[112].re = 18'h3ff8a;
    assign twiddles[112].im = 18'h3ffcf;
    assign twiddles[113].re = 18'h3ff89;
    assign twiddles[113].im = 18'h3ffd2;
    assign twiddles[114].re = 18'h3ff87;
    assign twiddles[114].im = 18'h3ffd5;
    assign twiddles[115].re = 18'h3ff86;
    assign twiddles[115].im = 18'h3ffd8;
    assign twiddles[116].re = 18'h3ff86;
    assign twiddles[116].im = 18'h3ffdb;
    assign twiddles[117].re = 18'h3ff85;
    assign twiddles[117].im = 18'h3ffde;
    assign twiddles[118].re = 18'h3ff84;
    assign twiddles[118].im = 18'h3ffe1;
    assign twiddles[119].re = 18'h3ff83;
    assign twiddles[119].im = 18'h3ffe4;
    assign twiddles[120].re = 18'h3ff82;
    assign twiddles[120].im = 18'h3ffe7;
    assign twiddles[121].re = 18'h3ff82;
    assign twiddles[121].im = 18'h3ffea;
    assign twiddles[122].re = 18'h3ff81;
    assign twiddles[122].im = 18'h3ffed;
    assign twiddles[123].re = 18'h3ff81;
    assign twiddles[123].im = 18'h3fff0;
    assign twiddles[124].re = 18'h3ff81;
    assign twiddles[124].im = 18'h3fff3;
    assign twiddles[125].re = 18'h3ff80;
    assign twiddles[125].im = 18'h3fff7;
    assign twiddles[126].re = 18'h3ff80;
    assign twiddles[126].im = 18'h3fffa;
    assign twiddles[127].re = 18'h3ff80;
    assign twiddles[127].im = 18'h3fffd;

    ////////////////////////////////////////////////////////////////////////////


endmodule