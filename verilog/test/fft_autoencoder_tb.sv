`timescale 1ns / 1ns

module fft_autoencoder_tb();
    import helper_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH    = 18;
    localparam FRACTION      = 7;
    localparam FFT_POINTS    = 256;
    localparam BUTTERFLIES   = 2;
    localparam PIPE_WIDTH    = 4;  

    logic clk;
    logic rst;

    logic fft_autoencoder_ready_in;
    logic fft_autoencoder_valid_in;
    logic [DATA_WIDTH-1:0] fft_autoencoder_data_in;

    logic fft_autoencoder_ready_out;
    logic fft_autoencoder_valid_out;
    logic [DATA_WIDTH-1:0] fft_autoencoder_data_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    fft_autoencoder #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION),
        .FFT_POINTS (FFT_POINTS),
        .BUTTERFLIES(BUTTERFLIES),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) fft_autoencoder (
        .clk    (clk),
        .rst    (rst),
        
        .fft_autoencoder_ready_in   (fft_autoencoder_ready_in),
        .fft_autoencoder_valid_in   (fft_autoencoder_valid_in),
        .fft_autoencoder_data_in    (fft_autoencoder_data_in),

        .fft_autoencoder_ready_out  (fft_autoencoder_ready_out),
        .fft_autoencoder_valid_out  (fft_autoencoder_valid_out),
        .fft_autoencoder_data_out   (fft_autoencoder_data_out)
    );


    int fd;
    string line;
    bit valid;
    logic [DATA_WIDTH-1:0] hex;
    int count;

    initial begin
        count = 0;
        fd = $fopen("../verilog/top/new_mr_train.hex", "r");
        fft_autoencoder_ready_out = 1'b0;
        fft_autoencoder_valid_in = 1'b0;
        fft_autoencoder_data_in = {DATA_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        while (!$feof(fd)) begin
            #(CLK_PERIOD);

            //fft_autoencoder_ready_out <= $urandom_range(1'b0, 1'b1);
            fft_autoencoder_ready_out <= 1'b1;
            // if (count < 1) begin
            //     count++;
            //     fft_autoencoder_valid_in <= 1'b0;
            // end else begin
            //     count = 0;
                if (fft_autoencoder_ready_in | ~fft_autoencoder_valid_in) begin
                    //valid = $urandom_range(1'b0, 1'b1);
                    valid = 1'b1;
                    $fgets(line, fd);
                    hex = line.atohex();
                    fft_autoencoder_data_in <= hex;
                    fft_autoencoder_valid_in <= valid;
                end
            //end

        end
        $fclose(fd);
        $stop;
    end


endmodule