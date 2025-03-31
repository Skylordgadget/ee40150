////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       mult_reduce.sv                                            //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Multiplies the incoming data streams and adds the result  //
//                  to an accumulator, resetting the accumulator after        //
//                  'NUM_ELEMENTS' data pairs.                                //
//                  I.e., result = accumulator + (dataa * datab).             //
//                                                                            //
//                  This implementation is basic, using a single multiplier   //
//                  as opposed to using many mutlipliers in parallel and      //
//                  reducing with log2 adders.                                //
//  TODO:           - Remove the need for an extra beat when resetting the    //
//                    accumulator                                             //
//                  - Replace the accumulator with accum.sv                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module mult_reduce (
    clk,
    rst,

    mult_reduce_ready_in,
    mult_reduce_valid_in,
    mult_reduce_dataa_in,
    mult_reduce_datab_in,

    mult_reduce_ready_out,
    mult_reduce_valid_out,
    mult_reduce_result_out
);
    import helper_pkg::*;

    parameter DATA_WIDTH = 12; // width of the incoming data
    parameter NUM_ELEMENTS = 5; // sequence length to accumulate over
    parameter PIPE_WIDTH = 2; // number of pipeline registers within the lpm_mult module

    localparam MULT_OUT_WIDTH = (DATA_WIDTH * 2); 
    localparam ELEMENT_COUNTER_WIDTH = clog2(NUM_ELEMENTS);

    // clock and reset interface
    input logic                         clk;
    input logic                         rst;

    // axi input interface 
    output  logic                       mult_reduce_ready_in;
    input   logic                       mult_reduce_valid_in;
    input   logic [DATA_WIDTH-1:0]      mult_reduce_dataa_in;
    input   logic [DATA_WIDTH-1:0]      mult_reduce_datab_in;

    // axi output interface
    input   logic                       mult_reduce_ready_out;
    output  logic                       mult_reduce_valid_out;
    output  logic [MULT_OUT_WIDTH-1:0]  mult_reduce_result_out; 

    // private signals
    logic [MULT_OUT_WIDTH-1:0]          mult_out;
    logic [ELEMENT_COUNTER_WIDTH-1:0]   count;
    logic [MULT_OUT_WIDTH-1:0]          accumulator;
    logic [PIPE_WIDTH-1:0]              valid_in_pipe;

    // valid_in pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            valid_in_pipe <= {PIPE_WIDTH{1'b0}};
        end else begin
            if (mult_reduce_ready_in) begin
                // shift the valid signal along the pipe only when ready is high
                valid_in_pipe <= {valid_in_pipe[PIPE_WIDTH-2:0], mult_reduce_valid_in};
            end
        end
    end

    // multiplier
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) multiplier (
        .clken  (mult_reduce_ready_in), // only clock data when ready is high
        .clock  (clk),
        .dataa  (mult_reduce_dataa_in),
        .datab  (mult_reduce_datab_in),
        .result (mult_out)
    );

    // reduce logic
    always_ff @(posedge clk) begin
        if (rst) begin
            // initialise all registers
            accumulator <= {MULT_OUT_WIDTH{1'b0}};
            count <= {ELEMENT_COUNTER_WIDTH{1'b0}};
            mult_reduce_valid_out <= 1'b0;
            mult_reduce_ready_in <= 1'b1;
            mult_reduce_result_out <= {MULT_OUT_WIDTH{1'b0}};
        end else begin
            /* when there is a handshake at the output, deassert valid to prevent
            duplicates and invalid data being clocked out */
            if (mult_reduce_valid_out && mult_reduce_ready_out) begin
                mult_reduce_valid_out <= 1'b0;
                mult_reduce_ready_in <= 1'b1;
            end

            // handle handshake at the input 
            if (valid_in_pipe[PIPE_WIDTH-1] && mult_reduce_ready_in) begin
                if (count < NUM_ELEMENTS-1) begin
                    // accumulate and increment the counter
                    accumulator <= accumulator + mult_out;
                    count <= count + 1'b1;
                end else begin
                    // reset the accumulator
                    accumulator <= {MULT_OUT_WIDTH{1'b0}};
                    // clock out the final result
                    mult_reduce_result_out <= accumulator + mult_out;
                    // reset the count
                    count <= {ELEMENT_COUNTER_WIDTH{1'b0}};
                    // data is valid, reserve a cycle for resetting
                    mult_reduce_valid_out <= 1'b1;
                    mult_reduce_ready_in <= 1'b0;
                end
            end
        end
    end

endmodule
