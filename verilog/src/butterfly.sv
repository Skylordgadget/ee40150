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

    assign Wb.re = (but_b_in.re * but_tw.re) - (but_b_in.im * but_tw.im); // change this later
    assign Wb.im = (but_b_in.re * but_tw.im) + (but_b_in.im * but_tw.re); // change this later

    assign but_a_out = but_a_in + Wb[MULT_OUT_MSB-:DATA_WIDTH]; // this is fine
    assign but_b_out = but_b_in - Wb[MULT_OUT_MSB-:DATA_WIDTH]; // this is fine

endmodule