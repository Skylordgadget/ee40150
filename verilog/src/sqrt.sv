module sqrt (
    clk,
    rst,

    sqrt_ready_in,
    sqrt_valid_in,
    sqrt_data_in,

    sqrt_ready_out,
    sqrt_valid_out,
    sqrt_data_out
);
    import helper_pkg::*;

    // state machine states
    typedef enum { 
        FLUSH,
        RUNNING,
        READY
    } state_t;

    parameter DATA_WIDTH = 8; // width of radicand                                                                  
    parameter FRACTION   = 8; // fractional bits (for fixed point)

    localparam ITER = (DATA_WIDTH + FRACTION) >> 1; // iterations are half radicand+fbits width
    localparam ITER_W = clog2(ITER);

    input logic clk;
    input logic rst;

    output  logic                   sqrt_ready_in;
    input   logic                   sqrt_valid_in;
    input   logic [DATA_WIDTH-1:0]  sqrt_data_in;

    input   logic                   sqrt_ready_out;
    output  logic                   sqrt_valid_out;
    output  logic [DATA_WIDTH-1:0]  sqrt_data_out;

    logic [DATA_WIDTH-1:0] x, x_next;   // radicand copy
    logic [DATA_WIDTH-1:0] q, q_next;   // intermediate sqrt_data_out (quotient)
    logic [DATA_WIDTH+1:0] ac, ac_next; // accumulator (2 bits wider)
    logic [DATA_WIDTH+1:0] test_res;    // sign test result (2 bits wider)

    logic [ITER_W-1:0] i; // iteration counter

    state_t state, next_state;

    /* while the system is idle, allow inputs
    TODO it *is* possible to eliminate the need for an idle state */
    assign sqrt_ready_in = (state == READY);

    // clock in next_state
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= READY;
        end else begin
            state <= next_state;
        end
    end 

    // determine next_state
    always_comb begin
        next_state = state;
        case (state)
            READY: begin /* if the incoming data is valid then transition to 
                running (valid && ready) */
                if (sqrt_valid_in) begin
                    next_state = RUNNING;
                end
            end
            RUNNING: begin /* while running, if the count finishes and the 
                downstream module is ready then transition to flush */
                if (i == ITER-1) begin
                    next_state = FLUSH;
                end
            end 
            FLUSH: begin /* if the downstream module is still ready 
            transition to idle */
                if (sqrt_ready_out) begin
                    next_state = READY;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            sqrt_valid_out <= 1'b0;
            sqrt_data_out <= {DATA_WIDTH{1'b0}};
            i <= {ITER_W{1'b0}};
            q <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                READY: begin
                    if (sqrt_valid_in) begin
                        {ac, x} <= {{DATA_WIDTH{1'b0}}, sqrt_data_in, 2'b0};
                    end
                end
                RUNNING: begin
                    if (i == ITER-1) begin  // we're done
                        sqrt_valid_out <= 1'b1;
                        sqrt_data_out <= q_next;
                    end else begin  // next iteration
                        i <= i + 1;
                        x <= x_next;
                        ac <= ac_next;
                        q <= q_next;
                    end
                end
                FLUSH: begin
                    if (sqrt_ready_out) begin
                        // only send valid low when next ready
                        sqrt_valid_out <= 1'b0;
                        i <= {ITER_W{1'b0}};
                        q <= {DATA_WIDTH{1'b0}};
                    end
                end
            endcase 
        end
    end

    always_comb begin
        test_res = ac - {q, 2'b01};
        if (test_res[DATA_WIDTH+1] == 0) begin  // test_res ≥0? (check MSB)
            {ac_next, x_next} = {test_res[DATA_WIDTH-1:0], x, 2'b0};
            q_next = {q[DATA_WIDTH-2:0], 1'b1};
        end else begin
            {ac_next, x_next} = {ac[DATA_WIDTH-1:0], x, 2'b0};
            q_next = q << 1;
        end
    end 

endmodule