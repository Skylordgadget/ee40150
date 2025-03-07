`include "./../pkg/fft_pkg.sv"

module fft_tb();
    import fft_pkg::*;

    localparam DATA_WIDTH = 16;
    localparam FRACTION = 11;
    localparam FFT_POINTS = 8;

    localparam CLK_PERIOD = 10;

    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    logic clk;
    logic rst;

    logic fft_ready_in;
    logic fft_valid_in;
    logic [DATA_WIDTH-1:0] fft_data_in;

    logic fft_ready_out;
    logic fft_valid_out;
    complex fft_data_out;

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    // testing zone (delete or commment out later)


    fft #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION),
        .FFT_POINTS (FFT_POINTS)
    ) fft (
        .clk        (clk),
        .rst        (rst),

        .fft_ready_in   (fft_ready_in),
        .fft_valid_in   (fft_valid_in),
        .fft_data_in    (fft_data_in),

        .fft_ready_out  (fft_ready_out),
        .fft_valid_out  (fft_valid_out),
        .fft_data_out   (fft_data_out)
    );

    initial begin
        rst = 1'b1;
        fft_valid_in <= 1'b0;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        fft_data_in <= 16'h0000;
        fft_valid_in <= 1'b1;
        #(CLK_PERIOD);
        fft_data_in <= 16'h0000;
        #(CLK_PERIOD);
        fft_data_in <= 16'h0800;
        #(CLK_PERIOD);
        fft_data_in <= 16'h1000;
        #(CLK_PERIOD);
        fft_data_in <= 16'h0000;
        #(CLK_PERIOD);
        fft_data_in <= 16'h0000;
        #(CLK_PERIOD);
        fft_data_in <= 16'h1000;
        #(CLK_PERIOD);
        fft_data_in <= 16'h0800;
        #(CLK_PERIOD);
        fft_valid_in <= 1'b0;
    end

endmodule
