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

    parameter DATA_WIDTH    = 12;
    parameter FRACTION      = 24; 
    parameter FFT_POINTS    = 8; // always a power of 2
    parameter BUTTERFLIES   = 4; // always a power of 2 shouldn't be more than FFT_POINTS / 2
    parameter PIPE_WIDTH    = 4;

    localparam FFT_POINTS_W = clog2(FFT_POINTS);
    localparam TWIDDLES = FFT_POINTS / 2;

    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    input logic clk;
    input logic rst;
    
    output logic                    fft_ready_in;
    input logic                     fft_valid_in;
    input logic [DATA_WIDTH-1:0]    fft_data_in;

    input logic                     fft_ready_out;
    output logic                    fft_valid_out;
    output complex                  fft_data_out    [0:FFT_POINTS-1];

    // s2complexp output interface
    logic s2complexp_ready_out;
    logic s2complexp_valid_out;
    complex s2complexp_parallel_out [0:FFT_POINTS-1];

    logic fft_stage_ready;
    logic fft_stage_1_ready;
    logic fft_stage_1_valid;
    complex fft_stage_1_data [0:FFT_POINTS-1];
    logic signed [DATA_WIDTH-1:0] a [0:TWIDDLES-1];
    logic signed [DATA_WIDTH-1:0] b [0:TWIDDLES-1];
    
    logic [FFT_POINTS_W-1:0] reversed_a [0:TWIDDLES-1]; 
    logic [FFT_POINTS_W-1:0] reversed_b [0:TWIDDLES-1];

    s2complexp #(
        .DATA_WIDTH     (DATA_WIDTH),
        .NUM_ELEMENTS   (FFT_POINTS)
    ) s2complexp (
        .clk            (clk),
        .rst            (rst),

        .s2complexp_ready_in    (fft_ready_in),
        .s2complexp_valid_in    (fft_valid_in),
        .s2complexp_serial_in   (fft_data_in),
        
        .s2complexp_ready_out   (s2complexp_ready_out),
        .s2complexp_valid_out   (s2complexp_valid_out),
        .s2complexp_parallel_out(s2complexp_parallel_out)
    );

    assign s2complexp_ready_out = fft_stage_ready | ~fft_stage_1_valid;

    /* stage 1 of the FFT doesn't need any multiplications so it doesn't need
    subdividing either */
    generate
        genvar i;

        for (i=0; i<TWIDDLES; i++) begin: fft_stage_1
            assign reversed_a[i] = reversebits(i*2)[31-:FFT_POINTS_W];
            assign reversed_b[i] = reversebits((i*2) + 1)[31-:FFT_POINTS_W];;
            assign a[i] = s2complexp_parallel_out[reversed_a[i]].re;
            assign b[i] = s2complexp_parallel_out[reversed_b[i]].re;

            always_ff @(posedge clk) begin
                if (rst) begin
                    fft_stage_1_valid <= 1'b0;
                    fft_stage_1_data[i*2] <= 'b0;
                    fft_stage_1_data[(i*2)+1] <= 'b0;
                end else begin
                    if (s2complexp_ready_out) begin
                        fft_stage_1_valid <= s2complexp_valid_out;
                        fft_stage_1_data[reversed_a[i]].re <= a[i] + b[i];
                        fft_stage_1_data[reversed_b[i]].re <= a[i] - b[i];
                    end
                end
            end 
        end
    endgenerate

    fft_stage #(
        .DATA_WIDTH     (DATA_WIDTH),
        .FRACTION       (FRACTION),
        .FFT_POINTS     (FFT_POINTS),
        .BUTTERFLIES    (BUTTERFLIES),
        .PIPE_WIDTH     (PIPE_WIDTH)
    ) fft_stage (
        .clk            (clk),
        .rst            (rst),

        .fft_stage_ready_in (fft_stage_ready),
        .fft_stage_valid_in (fft_stage_1_valid),
        .fft_stage_data_in  (fft_stage_1_data),

        .fft_stage_ready_out(fft_ready_out), 
        .fft_stage_valid_out(fft_valid_out), 
        .fft_stage_data_out (fft_data_out)
    );
                                               
endmodule