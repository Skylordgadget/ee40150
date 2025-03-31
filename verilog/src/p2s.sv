////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       p2s.sv                                                    //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Basic parallel to serial converter with an AXI interface. //
//                                                                            //
//                  This parallel to serial converter takes NUM_ELEMENTS      //
//                  that arrive in parallel and that are of width DATA_WIDTH  //
//                  and outputs them sequentially according to the AXI        //
//                  protocol using a simple state machine.                    //           
//  TODO:           - Add the option for pipeline registers--at the moment    //
//                    the lack of pipeline registers forces idle beats        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module p2s (
    clk,
    rst,

    p2s_ready_in,
    p2s_valid_in,
    p2s_parallel_in,

    p2s_ready_out,
    p2s_valid_out,
    p2s_serial_out
);
    import helper_pkg::*;

    parameter DATA_WIDTH = 12; // width of the incoming data
    parameter NUM_ELEMENTS = 5; // parallel width

    localparam ELEMENT_COUNTER_WIDTH = clog2(NUM_ELEMENTS); 

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    p2s_ready_in;
    input logic                     p2s_valid_in;
    input logic [DATA_WIDTH-1:0]    p2s_parallel_in [0:NUM_ELEMENTS-1];

    // axi output interface
    input logic                     p2s_ready_out;
    output logic                    p2s_valid_out;
    output logic [DATA_WIDTH-1:0]   p2s_serial_out;

    // private signals
    logic [DATA_WIDTH-1:0] parallel_reg [0:NUM_ELEMENTS-1];
    logic [ELEMENT_COUNTER_WIDTH-1:0] count;

    // state machine states
    typedef enum { 
        FLUSH,
        RUNNING,
        IDLE
    } state_t;

    state_t state, next_state;

    /* while the system is idle, allow inputs
    TODO it *is* possible to eliminate the need for an idle state */
    assign p2s_ready_in = (state == IDLE);
    
    // clock in next_state
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end 
    
    // determine next_state
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin /* if the incoming data is valid then transition to 
                running (valid && ready) */
                if (p2s_valid_in) begin
                    next_state = RUNNING;
                end
            end
            RUNNING: begin /* while running, if the count finishes and the 
                downstream module is ready then transition to flush */
                if ((count == NUM_ELEMENTS-1) && p2s_ready_out) begin
                    next_state = FLUSH;
                end
            end 
            FLUSH: begin /* if the downstream module is still ready 
            transition to idle */
                if (p2s_ready_out) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= {ELEMENT_COUNTER_WIDTH{1'b0}};
            p2s_serial_out <= {DATA_WIDTH{1'b0}};
            p2s_valid_out <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (p2s_valid_in) begin
                        // capture the next available valid parallel data
                        parallel_reg <= p2s_parallel_in;
                    end
                end
                RUNNING: begin
                    if (p2s_ready_out) begin
                        // outgoing data is always valid while running
                        p2s_valid_out <= 1'b1;
                        p2s_serial_out <= parallel_reg[count];
                        count <= count + 1'b1;
                    end 
                end
                FLUSH: begin
                    if (p2s_ready_out) begin
                        // only send valid low when next ready
                        p2s_valid_out <= 1'b0;
                        // flush the counter
                        count <= {ELEMENT_COUNTER_WIDTH{1'b0}};
                    end
                end
            endcase 
        end
    end


endmodule 