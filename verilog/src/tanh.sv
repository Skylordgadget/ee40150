module tanh (
    clk,
    rst,

    tanh_ready_in,
    tanh_valid_in,
    tanh_data_in,

    tanh_ready_out,
    tanh_valid_out,
    tanh_data_out
);
    import helper_pkg::*;

    parameter DATA_WIDTH = 16;
    parameter TANH_SAMPLES = 64;
    parameter TANH_LUT = "";
    parameter signed [DATA_WIDTH-1:0] TANH_MAX = 16'h03e0;
    parameter signed [DATA_WIDTH-1:0] TANH_MIN = 16'hfc00;
    parameter ID_MSB = 10; 
    parameter ID_LSB = 5;
    
    localparam RAM_ADDRESS_WIDTH = clog2(TANH_SAMPLES);

    input logic                     clk;
    input logic                     rst;

    output logic                    tanh_ready_in;
    input logic                     tanh_valid_in;
    input logic [DATA_WIDTH-1:0]    tanh_data_in;

    input logic                     tanh_ready_out;
    output logic                    tanh_valid_out;
    output logic [DATA_WIDTH-1:0]   tanh_data_out;    

    logic valid_d1, valid_d2;

    logic [RAM_ADDRESS_WIDTH-1:0]   tanh_id;
    logic signed [DATA_WIDTH-1:0] diff_min, mask_min;
    logic signed [DATA_WIDTH-1:0] diff_max, mask_max;
    logic signed [DATA_WIDTH-1:0] clamped_min, clamped_max;


    assign tanh_ready_in = tanh_ready_out | ~tanh_valid_out;

        // Compute difference from min and extract sign bit
    assign diff_min  = tanh_data_in - TANH_MIN;
    assign mask_min  = diff_min >>> (DATA_WIDTH-1); // Sign extension (0xFFFF... if negative, 0x0000 otherwise)
    assign clamped_min = (tanh_data_in & ~mask_min) | (TANH_MIN & mask_min); // If negative, force min

    // Compute difference from max and extract sign bit
    assign diff_max  = TANH_MAX - clamped_min;
    assign mask_max  = diff_max >>> (DATA_WIDTH-1); // Sign extension
    assign clamped_max = (clamped_min & ~mask_max) | (TANH_MAX & mask_max); // If negative, force max

    assign tanh_id = clamped_max[ID_MSB:ID_LSB];

    sp_ram_clken #(
        .WIDTH          (DATA_WIDTH),
        .DEPTH          (TANH_SAMPLES),
        .INIT_FILE      (TANH_LUT),
        .ADDRESS_WIDTH  (RAM_ADDRESS_WIDTH)
    ) tanh_lut (
        .address    (tanh_id),
        .clock      (clk),
        .clken      (tanh_ready_in),
        .data       (), // unconnected (for now)
        .rden       (1'b1), // tied high (for now) 
        .wren       (1'b0), // tied low (for now)
        .q          (tanh_data_out)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            tanh_data_out <= {DATA_WIDTH{1'b0}};
            tanh_valid_out <= 1'b0;
            valid_d1 <= 1'b0;
            valid_d2 <= 1'b0;
        end else begin
            valid_d1 <= tanh_valid_in;
            valid_d2 <= valid_d1;
            tanh_valid_out <= valid_d2;
        end
    end


endmodule