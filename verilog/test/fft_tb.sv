module fft_tb();
    logic clk;
    logic rst;

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    // testing zone (delete or commment out later)

    real x0 = 1;
    real x1 = 1;

    real y0 = 0;
    real y1 = 0;

    real twiddle = 1;

    initial begin
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        
    end

endmodule
