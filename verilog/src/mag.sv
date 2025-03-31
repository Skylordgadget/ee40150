module mag(
    clk,
    rst,

    mag_ready_in,
    mag_valid_in,
    mag_dataa_in,
    mag_datab_in,

    mag_ready_out,
    mag_valid_out,
    mag_data_out
);
    import helper_pkg::*;

    parameter DATA_WIDTH = 16;
    parameter FRACTION   = 8;
    parameter PIPE_WIDTH = 4;

    localparam FRACTIONAL_BITS = FRACTION;
    localparam INTEGER_BITS = (DATA_WIDTH-FRACTION);

    // capture the entire possible width of a multiplier output (no truncation)
    localparam LPM_OUT_WIDTH = DATA_WIDTH * 2; 

    // where the MSB will be when computing a multiplication
    // from the MSB -: DATA_WIDTH to correctly truncate the data
    localparam LPM_OUT_MSB = (LPM_OUT_WIDTH - 1) - (DATA_WIDTH - FRACTION); 


    input logic clk;
    input logic rst;

    output logic                    mag_ready_in;
    input logic                     mag_valid_in;
    input logic [DATA_WIDTH-1:0]    mag_dataa_in;
    input logic [DATA_WIDTH-1:0]    mag_datab_in;

    input logic                     mag_ready_out;
    output logic                    mag_valid_out;
    output logic [DATA_WIDTH-1:0]   mag_data_out;

    logic [PIPE_WIDTH-1:0] valid_in_pipe;

    logic [LPM_OUT_WIDTH-1:0] mult_a_out;
    logic [LPM_OUT_WIDTH-1:0] mult_b_out;
    
    logic sqrt_ready_in;
    logic sqrt_valid_in;
    logic [LPM_OUT_WIDTH-1:0] sqrt_data_in, sqrt_data_out;


    // valid_in pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            valid_in_pipe <= {PIPE_WIDTH{1'b0}};
        end else begin
            if (mag_ready_in) begin
                // shift the valid signal along the pipe only when ready is high
                valid_in_pipe <= {valid_in_pipe[PIPE_WIDTH-2:0], mag_valid_in};
            end
        end
    end

    assign mag_ready_in = sqrt_ready_in | ~sqrt_valid_in;

    // a^2
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) mult_a (
        .clken  (mag_ready_in), // only clock data when ready is high
        .clock  (clk),
        .dataa  (mag_dataa_in),
        .datab  (mag_dataa_in),
        .result (mult_a_out)
    );

    // b^2
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) mult_b (
        .clken  (mag_ready_in), // only clock data when ready is high
        .clock  (clk),
        .dataa  (mag_datab_in),
        .datab  (mag_datab_in),
        .result (mult_b_out)
    );    

    assign sqrt_data_in = mult_a_out + mult_b_out;
    assign sqrt_valid_in = valid_in_pipe[PIPE_WIDTH-1];

    sqrt #(
        .DATA_WIDTH (LPM_OUT_WIDTH),
        .FRACTION   (2*FRACTION)
    ) sqrt (
        .clk            (clk),
        .rst            (rst),
        
        .sqrt_ready_in  (sqrt_ready_in),
        .sqrt_valid_in  (sqrt_valid_in),
        .sqrt_data_in   (sqrt_data_in),

        .sqrt_ready_out (mag_ready_out),
        .sqrt_valid_out (mag_valid_out),
        .sqrt_data_out  (sqrt_data_out)
    );

    assign mag_data_out = sqrt_data_out[LPM_OUT_MSB-:DATA_WIDTH];

endmodule