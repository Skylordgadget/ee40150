// synthesis translate_off
`include "./../pkg/fft_pkg.sv"
// synthesis translate_on

module butterfly (
    clk,
    rst,

    but_ready_in,
    but_valid_in,
    but_a_in,
    but_b_in,
    but_tw,

    but_ready_out,
    but_valid_out,
    but_a_out,
    but_b_out
);
    import fft_pkg::*;

    parameter DATA_WIDTH = 12;
    parameter FRACTION  = 24; 

    localparam FRACTIONAL_BITS = FRACTION;
    localparam INTEGER_BITS = (DATA_WIDTH-FRACTION);

    // capture the entire possible width of a multiplier output (no truncation)
    localparam MULT_OUT_WIDTH = DATA_WIDTH * 2; 

    // where the MSB will be when computing a multiplication
    // from the MSB -: DATA_WIDTH to correctly truncate the data
    localparam MULT_OUT_MSB = (MULT_OUT_WIDTH - 1) - (DATA_WIDTH - FRACTION); 

    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    typedef struct packed {
        logic signed [MULT_OUT_WIDTH-1:0] re;
        logic signed [MULT_OUT_WIDTH-1:0] im;
    } complex_double;

    input logic clk;
    input logic rst;

    output logic but_ready_in;
    input logic but_valid_in;
    input complex but_a_in;
    input complex but_b_in;
    input complex but_tw;

    input logic but_ready_out;
    output logic but_valid_out;
    output complex but_a_out;
    output complex but_b_out;

    complex_double Wb;
    complex Wb_truncated;
    logic [DATA_WIDTH-1:0] minus_1;

    assign minus_1 = {1'b1, {(INTEGER_BITS-1){1'b1}}, {FRACTIONAL_BITS{1'b0}}};

    assign Wb.re = (but_b_in.re * but_tw.re) - (but_b_in.im * but_tw.im); // change this later
    assign Wb.im = (but_b_in.re * but_tw.im) + (but_b_in.im * but_tw.re); // change this later

    assign Wb_truncated.re = Wb.re[MULT_OUT_MSB-:DATA_WIDTH];
    assign Wb_truncated.im = Wb.im[MULT_OUT_MSB-:DATA_WIDTH];

    assign but_a_out.re = but_a_in.re + Wb_truncated.re; // this is fine
    assign but_a_out.im = but_a_in.im + Wb_truncated.im; // this is fine
    assign but_b_out.re = but_a_in.re - Wb_truncated.re; // this is fine
    assign but_b_out.im = but_a_in.im - Wb_truncated.im; // this is fine

endmodule