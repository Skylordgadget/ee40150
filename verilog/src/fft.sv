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
    localparam NUM_TWIDDLES = FFT_POINTS >> 1; 

    /* testing, remove this later =========================================== */
    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    input logic clk;
    input logic rst;
    
    output logic fft_ready_in;
    input logic fft_valid_in;
    input logic [DATA_WIDTH-1:0] fft_data_in;

    input logic fft_ready_out;
    output logic fft_valid_out;
    output complex fft_data_out;

    complex twiddle8 [0:NUM_TWIDDLES-1]; // complex number
    complex buf [0:FFT_POINTS-1:0];
    complex stage1 [0:FFT_POINTS-1:0];
    complex stage2 [0:FFT_POINTS-1:0];
    complex stage3 [0:FFT_POINTS-1:0];
    /*
        1000, 0000
        0b50, f4b0
        0000, f000
        f4b0, f4b0
    */
    assign twiddle8[0].re = 16'h1000;
    assign twiddle8[0].im = 16'h0000;

    assign twiddle8[1].re = 16'h0b50;
    assign twiddle8[1].im = 16'hf4b0;

    assign twiddle8[2].re = 16'h0000;
    assign twiddle8[2].im = 16'hf000;

    assign twiddle8[3].re = 16'hf4b0;
    assign twiddle8[3].im = 16'hf4b0;

    /* ====================================================================== */
    
    always_ff @(posedge clk) begin
        if (rst) begin
            fft_data_out <= 'b0;
        end else begin
            buf <= {buf[FFT_POINTS-1:1], fft_data_in};
        end
    end


    generate;
        genvar s1;
        for (s1=0; s1<NUM_TWIDDLES; s1++) begin
            butterfly #(
                .DATA_WIDTH (DATA_WIDTH),
                .FRACTION   (FRACTION),
            ) butterfly (
                .clk (clk),
                .rst (rst),

                .but_ready_in (),
                .but_valid_in (),
                .but_a_in ( buf[ reversebits(s1*2) ] ),
                .but_b_in ( buf[ reversebits((s1*2)+1) ] ),
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
        for (s2=0; s2<NUM_TWIDDLES; s2++) begin
            butterfly #(
                .DATA_WIDTH (DATA_WIDTH),
                .FRACTION   (FRACTION),
            ) butterfly (
                .clk (clk),
                .rst (rst),

                .but_ready_in (),
                .but_valid_in (),
                .but_a_in ( stage1[ reversebits(s2*2) ] ),
                .but_b_in ( stage1[ reversebits((s2*2)+1) ] ),
                .but_tw   ( twiddle8[0] ),

                .but_ready_out (),
                .but_valid_out (),
                .but_a_out (stage2[ s2*2 ]),
                .but_b_out (stage2[ (s2*2)+1 ])
            );
        end
    endgenerate

    generate;
        genvar s1;
        for (s1=0; s1<NUM_TWIDDLES; s1++) begin
            butterfly #(
                .DATA_WIDTH (DATA_WIDTH),
                .FRACTION   (FRACTION),
            ) butterfly (
                .clk (clk),
                .rst (rst),

                .but_ready_in (),
                .but_valid_in (),
                .but_a_in ( buf[ reversebits(s1*2) ] ),
                .but_b_in ( buf[ reversebits((s1*2)+1) ] ),
                .but_tw   ( twiddle8[0] ),

                .but_ready_out (),
                .but_valid_out (),
                .but_a_out (stage1[ s1*2 ]),
                .but_b_out (stage1[ (s1*2)+1 ])
            );
        end
    endgenerate

endmodule