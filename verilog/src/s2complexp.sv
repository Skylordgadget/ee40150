module s2complexp (
    clk,
    rst,

    s2complexp_ready_in,
    s2complexp_valid_in,
    s2complexp_serial_in,

    s2complexp_ready_out,
    s2complexp_valid_out,
    s2complexp_parallel_out
);
    import helper_pkg::*;

    parameter DATA_WIDTH = 12; // width of the incoming data
    parameter NUM_ELEMENTS = 5; // parallel width    

    localparam ELEMENT_COUNTER_WIDTH = clog2(NUM_ELEMENTS); 
    
    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    s2complexp_ready_in;
    input logic                     s2complexp_valid_in;
    input logic [DATA_WIDTH-1:0]    s2complexp_serial_in;

    // axi output interface
    input logic                     s2complexp_ready_out;
    output logic                    s2complexp_valid_out;
    output complex                  s2complexp_parallel_out [0:NUM_ELEMENTS-1];

    // private signals
    logic [ELEMENT_COUNTER_WIDTH-1:0] count;

    assign s2complexp_ready_in = ~s2complexp_valid_out | s2complexp_ready_out;

    always_ff @(posedge clk) begin
        if (rst) begin
            s2complexp_valid_out <= 1'b0;
            count <= {ELEMENT_COUNTER_WIDTH{1'b0}};
        end else begin    
            if (s2complexp_ready_in) begin
                s2complexp_valid_out <= 1'b0;
                if (s2complexp_valid_in) begin
                    count <= count + 1'b1;
                    s2complexp_parallel_out[count] <= {s2complexp_serial_in, {DATA_WIDTH{1'b0}}};
                    s2complexp_valid_out <= (count == NUM_ELEMENTS-1);
                end
            end 
        end
    end


endmodule