module butterfly (
    clk,
    rst,

    clken,

    butterfly_a_in,
    butterfly_b_in,
    butterfly_tw,

    butterfly_a_out,
    butterfly_b_out
);
    import fft_pkg::*;

    parameter DATA_WIDTH = 12;
    parameter FRACTION  = 24; 
    parameter PIPE_WIDTH = 4;

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

    input logic clken;

    input complex   butterfly_a_in;
    input complex   butterfly_b_in;
    input complex   butterfly_tw;

    output complex  butterfly_a_out;
    output complex  butterfly_b_out;

    logic signed [MULT_OUT_WIDTH-1:0] re_re, im_im, re_im, im_re;

    complex_double Wb;
    complex Wb_truncated;

    complex a_in_pipe [0:PIPE_WIDTH];

    always_ff @(posedge clk) begin
        if (clken) begin
            a_in_pipe <= {butterfly_a_in, a_in_pipe[0:PIPE_WIDTH-1]};
        end
    end

    // butterfly_b_in.re * butterfly_tw.re
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) re_x_re (
        .clken  (clken), // only clock data when ready is high
        .clock  (clk),
        .dataa  (butterfly_b_in.re),
        .datab  (butterfly_tw.re),
        .result (re_re)
    );

    // butterfly_b_in.im * butterfly_tw.im
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) im_x_im (
        .clken  (clken), // only clock data when ready is high
        .clock  (clk),
        .dataa  (butterfly_b_in.im),
        .datab  (butterfly_tw.im),
        .result (im_im)
    );

    // butterfly_b_in.re * butterfly_tw.im
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) re_x_im (
        .clken  (clken), // only clock data when ready is high
        .clock  (clk),
        .dataa  (butterfly_b_in.re),
        .datab  (butterfly_tw.im),
        .result (re_im)
    );

    // butterfly_b_in.im * butterfly_tw.re
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) im_x_re (
        .clken  (clken), // only clock data when ready is high
        .clock  (clk),
        .dataa  (butterfly_b_in.im),
        .datab  (butterfly_tw.re),
        .result (im_re)
    );

    assign Wb_truncated.re = Wb.re[MULT_OUT_MSB-:DATA_WIDTH]; // grab the right part
    assign Wb_truncated.im = Wb.im[MULT_OUT_MSB-:DATA_WIDTH]; // grab the right part

    always_ff @(posedge clk) begin
        if (rst) begin
            Wb <= 'b0;
            
            butterfly_a_out <= 'b0;
            butterfly_b_out <= 'b0;
            
        end else begin
            if (clken) begin
                Wb.re <= re_re - im_im;
                Wb.im <= re_im + im_re;

                butterfly_a_out.re <= a_in_pipe[PIPE_WIDTH].re + Wb_truncated.re;
                butterfly_a_out.im <= a_in_pipe[PIPE_WIDTH].im + Wb_truncated.im;
                butterfly_b_out.re <= a_in_pipe[PIPE_WIDTH].re - Wb_truncated.re;
                butterfly_b_out.im <= a_in_pipe[PIPE_WIDTH].im - Wb_truncated.im;
            end
        end 
    end

endmodule