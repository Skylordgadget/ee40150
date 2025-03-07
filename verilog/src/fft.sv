// synthesis translate_off
`include "./../pkg/fft_pkg.sv"
// synthesis translate_on

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
    import fft_pkg::*;

    parameter DATA_WIDTH = 12;
    parameter FRACTION  = 24; 

    parameter FFT_POINTS = 8; // always a power of 2
    localparam NUM_TWIDDLES = FFT_POINTS / 2; 

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
    output complex fft_data_out;

    complex twiddle8 [0:NUM_TWIDDLES-1]; // complex number
    complex shift_reg [0:FFT_POINTS-1];
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
    
    always_ff @(posedge clk) begin
        if (rst) begin
            fft_data_out <= 'b0;
        end else begin
            if (fft_valid_in) begin
                shift_reg <= {{fft_data_in,{DATA_WIDTH{1'b0}}}, shift_reg[0:FFT_POINTS-2]};
            end
        end
    end


    generate;
        genvar s1;
        for (s1=0; s1<NUM_TWIDDLES; s1++) begin: STAGE_1
            butterfly #(
                .DATA_WIDTH (DATA_WIDTH),
                .FRACTION   (FRACTION)
            ) butterfly (
                .clk (clk),
                .rst (rst),

                .but_ready_in (),
                .but_valid_in (),
                .but_a_in ( shift_reg[ reversebits(s1*2)[31-:3] ] ),
                .but_b_in ( shift_reg[ reversebits((s1*2)+1)[31-:3] ] ),
                .but_tw   ( twiddle8[0] ),

                .but_ready_out (),
                .but_valid_out (),
                .but_a_out (stage1[ s1*2 ]),
                .but_b_out (stage1[ (s1*2)+1 ])
            );
        end
    endgenerate

    generate;
        genvar s2;


        for (s2=0; s2<NUM_TWIDDLES; s2++) begin: STAGE_2
            butterfly #(
                .DATA_WIDTH (DATA_WIDTH),
                .FRACTION   (FRACTION)
            ) butterfly (
                .clk (clk),
                .rst (rst),

                .but_ready_in (),
                .but_valid_in (),
                .but_a_in ( stage1[ 2*s2 - (s2 % 2) ] ),
                .but_b_in ( stage1[ 2*s2 - (s2 % 2) + 2 ] ),
                .but_tw   ( twiddle8[(s2 % 2) * 2] ),

                .but_ready_out (),
                .but_valid_out (),
                .but_a_out (stage2[ 2*s2 - (s2 % 2) ]),
                .but_b_out (stage2[ 2*s2 - (s2 % 2) + 2 ])
            );
        end
    endgenerate

    generate;
        genvar s3;
        for (s3=0; s3<NUM_TWIDDLES; s3++) begin: STAGE_3
            butterfly #(
                .DATA_WIDTH (DATA_WIDTH),
                .FRACTION   (FRACTION)
            ) butterfly (
                .clk (clk),
                .rst (rst),

                .but_ready_in (),
                .but_valid_in (),
                .but_a_in ( stage2[ s3 ] ),
                .but_b_in ( stage2[ s3 + 4 ] ),
                .but_tw   ( twiddle8[s3] ),

                .but_ready_out (),
                .but_valid_out (),
                .but_a_out (stage3[ s3 ]),
                .but_b_out (stage3[ s3 + 4 ])
            );
        end
    endgenerate

endmodule