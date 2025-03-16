`timescale 1ns / 1ns

`include "./../pkg/helper_pkg.sv"

module s2complexp_tb();
    import helper_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam NUM_ELEMENTS = 64;
    
    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    typedef complex complexp_t [NUM_ELEMENTS];

    logic clk;
    logic rst;

    logic s2complexp_ready_in;
    logic s2complexp_valid_in;
    logic [DATA_WIDTH-1:0] s2complexp_serial_in;

    logic s2complexp_ready_out;
    logic s2complexp_valid_out;
    complex s2complexp_parallel_out [0:NUM_ELEMENTS-1];

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    s2complexp #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_ELEMENTS (NUM_ELEMENTS)
    ) s2complexp (
        .clk    (clk),
        .rst    (rst),

        .s2complexp_ready_in   (s2complexp_ready_in),
        .s2complexp_valid_in   (s2complexp_valid_in),
        .s2complexp_serial_in   (s2complexp_serial_in),

        .s2complexp_ready_out  (s2complexp_ready_out),
        .s2complexp_valid_out  (s2complexp_valid_out),
        .s2complexp_parallel_out    (s2complexp_parallel_out)
    );

    int unsigned num_inputs = 10000;

    mailbox mbx = new(num_inputs);

    bit valid;
    bit ready;
    int unsigned valid_cnt = 0;
    int unsigned valid_results = 0;

    complexp_t rand_data_complexp;

    bit valid_queue[$];                                                         
    logic [DATA_WIDTH-1:0] rand_data_queue[$];      


    logic [DATA_WIDTH-1:0] rand_data;

    initial begin
        for (int i=0; i<num_inputs; i++) begin
            //valid = $urandom_range(1'b0, 1'b1);
            valid = 1'b1;
            rand_data = $urandom_range(0, 10);

            valid_queue.push_back(valid);
            rand_data_queue.push_back(rand_data);

            if (valid) begin
                rand_data_complexp[valid_cnt] = {rand_data, {DATA_WIDTH{1'b0}}};
                valid_cnt++;
            end

            if (valid_cnt == NUM_ELEMENTS) begin
                valid_cnt = 0;
                //$display("put %p in the mailbox", rand_data_complexp);
                mbx.put(rand_data_complexp);
            end
        end

        s2complexp_ready_out = 1'b0;
        s2complexp_valid_in = 1'b0;
        s2complexp_serial_in = {DATA_WIDTH{1'b0}};

        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        valid_results = 0;
        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            //s2complexp_ready_out <= $urandom_range(1'b0, 1'b1);
            s2complexp_ready_out <= 1'b1;
            if (s2complexp_ready_in | ~s2complexp_valid_in) begin
                s2complexp_serial_in <= rand_data_queue.pop_front();
                s2complexp_valid_in <= valid_queue.pop_front();
            end
        end
        $display("test successful");
        $stop;
    end

    initial begin
        complexp_t mbx_received;
        int sum;
        forever begin
            #(CLK_PERIOD);
            if (s2complexp_valid_out && s2complexp_ready_out) begin
                mbx.get(mbx_received);
                if (!(mbx_received == s2complexp_parallel_out)) begin
                    $display("discrepency between expected value: %p, and received value: %p", mbx_received, s2complexp_parallel_out);
                    $stop;
                end
            end
        end
    end



endmodule