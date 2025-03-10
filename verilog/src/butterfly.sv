module butterfly (
    clk,
    rst,

    butterfly_ready_in,
    butterfly_valid_in,
    butterfly_a_in,
    butterfly_b_in,
    butterfly_tw,

    butterfly_ready_out,
    butterfly_valid_out,
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

    output logic    butterfly_ready_in;
    input logic     butterfly_valid_in;
    input complex   butterfly_a_in;
    input complex   butterfly_b_in;
    input complex   butterfly_tw;

    input logic     butterfly_ready_out;
    output logic    butterfly_valid_out;
    output complex  butterfly_a_out;
    output complex  butterfly_b_out;

    logic signed [MULT_OUT_WIDTH-1:0] re_re, im_im, re_im, im_re;

    logic Wb_valid;
    complex_double Wb;

    complex Wb_truncated;

    logic [PIPE_WIDTH-1:0] valid_in_pipe;

    // valid_in pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            valid_in_pipe <= {PIPE_WIDTH{1'b0}};
        end else begin
            if (butterfly_ready_in) begin
                // shift the valid signal along the pipe only when ready is high
                valid_in_pipe <= {valid_in_pipe[PIPE_WIDTH-2:0], butterfly_valid_in};
            end
        end
    end

    // butterfly_b_in.re * butterfly_tw.re
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) re_x_re (
        .clken  (butterfly_ready_in), // only clock data when ready is high
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
        .clken  (butterfly_ready_in), // only clock data when ready is high
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
        .clken  (butterfly_ready_in), // only clock data when ready is high
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
        .clken  (butterfly_ready_in), // only clock data when ready is high
        .clock  (clk),
        .dataa  (butterfly_b_in.im),
        .datab  (butterfly_tw.re),
        .result (im_re)
    );

    assign Wb_truncated.re = Wb.re[MULT_OUT_MSB-:DATA_WIDTH]; // grab the right part
    assign Wb_truncated.im = Wb.im[MULT_OUT_MSB-:DATA_WIDTH]; // grab the right part

    always_ff @(posedge clk) begin
        if (rst) begin
            Wb_valid <= 1'b0;
            Wb <= 'b0;
            
            butterfly_a_out <= 'b0;
            butterfly_b_out <= 'b0;
            
            butterfly_valid_out <= 1'b0;
        end else begin
            Wb_valid <= valid_in_pipe[PIPE_WIDTH-1];
            Wb.re <= re_re - im_im;
            Wb.im <= re_im + im_re;

            butterfly_valid_out <= Wb_valid;
            butterfly_a_out.re <= butterfly_a_in.re + Wb_truncated.re;
            butterfly_a_out.im <= butterfly_a_in.im + Wb_truncated.im;
            butterfly_b_out.re <= butterfly_a_in.re - Wb_truncated.re;
            butterfly_b_out.im <= butterfly_a_in.im - Wb_truncated.im;
        end 
    end

    assign butterfly_ready_in = rst ? 1'b0 : ~butterfly_valid_out | butterfly_ready_out;

endmodule