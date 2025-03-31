module fft_autoencoder (
    clk,
    rst,

    fft_autoencoder_ready_in,
    fft_autoencoder_valid_in,
    fft_autoencoder_data_in,

    fft_autoencoder_ready_out,
    fft_autoencoder_valid_out,
    fft_autoencoder_data_out
);

    import helper_pkg::*;

    parameter DATA_WIDTH    = 32;
    parameter FRACTION      = 16;
    parameter FFT_POINTS    = 256;
    parameter BUTTERFLIES   = 4;
    parameter PIPE_WIDTH    = 4;  

    localparam RSHIFT = clog2(FFT_POINTS);

    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    input logic clk;
    input logic rst;

    output logic                    fft_autoencoder_ready_in;
    input logic                     fft_autoencoder_valid_in;
    input logic [DATA_WIDTH-1:0]    fft_autoencoder_data_in;

    input logic                     fft_autoencoder_ready_out;
    output logic                    fft_autoencoder_valid_out;
    output logic [DATA_WIDTH-1:0]   fft_autoencoder_data_out;

    logic       fft_ready_out;
    logic       fft_valid_out;
    complex     fft_data_out [0:FFT_POINTS-1];

    logic       p2s_complex_ready_out;
    logic       p2s_complex_valid_out;
    complex     p2s_complex_serial_out;    

    fft #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION),
        .FFT_POINTS (FFT_POINTS),
        .BUTTERFLIES(BUTTERFLIES),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) fft (
        .clk    (clk),
        .rst    (rst),

        .fft_ready_in   (fft_autoencoder_ready_in),          
        .fft_valid_in   (fft_autoencoder_valid_in),          
        .fft_data_in    (fft_autoencoder_data_in),

        .fft_ready_out  (fft_ready_out),
        .fft_valid_out  (fft_valid_out),
        .fft_data_out   (fft_data_out)
    );

    p2s_complex #(
        .DATA_WIDTH     (DATA_WIDTH),
        .NUM_ELEMENTS   (FFT_POINTS) 
    ) p2s_complex (
        .clk    (clk),
        .rst    (rst),

        .p2s_complex_ready_in   (fft_ready_out),
        .p2s_complex_valid_in   (fft_valid_out),
        .p2s_complex_parallel_in(fft_data_out),

        .p2s_complex_ready_out  (p2s_complex_ready_out),  
        .p2s_complex_valid_out  (p2s_complex_valid_out),
        .p2s_complex_serial_out (p2s_complex_serial_out)  
    );

    mag #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) mag (
        .clk    (clk),
        .rst    (rst),

        .mag_ready_in   (p2s_complex_ready_out),
        .mag_valid_in   (p2s_complex_valid_out),
        .mag_dataa_in   (p2s_complex_serial_out.re >>> RSHIFT),
        .mag_datab_in   (p2s_complex_serial_out.im >>> RSHIFT),

        .mag_ready_out  (fft_autoencoder_ready_out),
        .mag_valid_out  (fft_autoencoder_valid_out),
        .mag_data_out   (fft_autoencoder_data_out)
    );

endmodule