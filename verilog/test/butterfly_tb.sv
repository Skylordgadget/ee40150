`timescale 1ns / 1ns

`include "./../pkg/helper_pkg.sv"

module butterfly_tb();
    import helper_pkg::*;
    
    localparam CLK_PERIOD = 10;

    localparam DATA_WIDTH   = 32;
    localparam FRACTION     = 16;
    localparam PIPE_WIDTH   = 4;
    
    localparam FRACTIONAL_BITS = FRACTION;
    localparam INTEGER_BITS = (DATA_WIDTH-FRACTION);

    // capture the entire possible width of a multiplier output (no truncation)
    localparam MULT_OUT_WIDTH = DATA_WIDTH * 2; 

    // where the MSB will be when computing a multiplication
    // from the MSB -: DATA_WIDTH to correctly truncate the data
    localparam MULT_OUT_MSB = (MULT_OUT_WIDTH - 1) - (DATA_WIDTH - FRACTION); 

    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex;

    typedef struct packed {
        logic signed [MULT_OUT_WIDTH-1:0] re;
        logic signed [MULT_OUT_WIDTH-1:0] im;
    } complex_double;

    logic clk;
    logic rst;

    logic   butterfly_ready_in;
    logic   butterfly_valid_in;
    complex butterfly_a_in;
    complex butterfly_b_in;
    complex butterfly_tw;

    logic   butterfly_ready_out;
    logic   butterfly_valid_out;
    complex butterfly_a_out;
    complex butterfly_b_out;



    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    butterfly #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) butterfly (
        .clk    (clk),
        .rst    (rst),

        .butterfly_ready_in     (butterfly_ready_in),        
        .butterfly_valid_in     (butterfly_valid_in),        
        .butterfly_a_in         (butterfly_a_in),    
        .butterfly_b_in         (butterfly_b_in),    
        .butterfly_tw           (butterfly_tw),

        .butterfly_ready_out    (butterfly_ready_out),    
        .butterfly_valid_out    (butterfly_valid_out),    
        .butterfly_a_out        (butterfly_a_out),
        .butterfly_b_out        (butterfly_b_out)
    );

    int unsigned num_inputs = 1000;

    mailbox mbx_a = new(num_inputs);
    mailbox mbx_b = new(num_inputs);

    bit valid;
    bit ready;

    bit valid_queue[$];                                                         
    complex rand_a_queue[$];
    complex rand_b_queue[$];      
    complex rand_tw_queue[$];

    complex rand_a;
    complex rand_b;
    complex rand_tw;

    complex_double Wb;
    complex Wb_truncated;
    complex a_out;
    complex b_out;

    initial begin
        for (int i=0; i<num_inputs; i++) begin
            valid = $urandom_range(1'b0, 1'b1);
            //valid = 1'b1;
            rand_a.re = $urandom_range(0, 10);
            rand_a.im = $urandom_range(0, 10);
            rand_b.re = $urandom_range(0, 10);
            rand_b.im = $urandom_range(0, 10);
            rand_tw.re = $urandom_range(0, 10);
            rand_tw.im = $urandom_range(0, 10);

            valid_queue.push_back(valid);
            rand_a_queue.push_back(rand_a);
            rand_b_queue.push_back(rand_b);
            rand_tw_queue.push_back(rand_tw);

            if (valid) begin
                Wb.re = (rand_b.re * rand_tw.re) - (rand_b.im * rand_tw.im);
                Wb.im = (rand_b.re * rand_tw.im) + (rand_b.im * rand_tw.re);
                Wb_truncated.re = Wb.re[MULT_OUT_MSB-:DATA_WIDTH];
                Wb_truncated.im = Wb.im[MULT_OUT_MSB-:DATA_WIDTH];
                a_out.re = rand_a.re + Wb_truncated.re;
                a_out.im = rand_a.im + Wb_truncated.im;
                b_out.re = rand_a.re - Wb_truncated.re;
                b_out.im = rand_a.im - Wb_truncated.im;

                //$display("put %p and %p in the mailbox", a_out, b_out);
                mbx_a.put(a_out);
                mbx_b.put(b_out);
            end
        end

        butterfly_ready_out = 1'b0;
        butterfly_valid_in = 1'b0;
        butterfly_a_in = 'b0;
        butterfly_b_in = 'b0;
        butterfly_tw = 'b0;

        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            butterfly_ready_out <= $urandom_range(1'b0, 1'b1);
            //butterfly_ready_out <= 1'b1;
            if (butterfly_ready_in | ~butterfly_valid_in) begin
                butterfly_valid_in <= valid_queue.pop_front();
                butterfly_a_in <= rand_a_queue.pop_front();
                butterfly_b_in <= rand_b_queue.pop_front();
                butterfly_tw <= rand_tw_queue.pop_front();
            end
        end
        $display("test successful");
        $stop;
    end

    initial begin
        complex mbx_a_received;
        complex mbx_b_received;
        int sum;
        forever begin
            #(CLK_PERIOD);
            if (butterfly_valid_out && butterfly_ready_out) begin
                mbx_a.get(mbx_a_received);
                mbx_b.get(mbx_b_received);
                $display("tb a_out: %p, dut a_out: %p", mbx_a_received, butterfly_a_out);
                $display("tb b_out: %p, dut b_out: %p", mbx_b_received, butterfly_b_out);
                $stop;
                if ((mbx_a_received != butterfly_a_out) || (mbx_b_received != butterfly_b_out)) begin
                    $display("discrepency between expected value: %p %p, and received value: %p %p", mbx_a_received, mbx_b_received, butterfly_a_out, butterfly_b_out);
                    $stop;
                end
            end
        end
    end



endmodule