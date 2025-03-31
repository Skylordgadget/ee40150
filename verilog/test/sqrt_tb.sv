`timescale 1ns / 1ns

`include "./../pkg/helper_pkg.sv"

module sqrt_tb();
    import helper_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 16;
    localparam FRACTION = 8;

    logic clk;
    logic rst;

    logic                   sqrt_ready_in;
    logic                   sqrt_valid_in;
    logic [DATA_WIDTH-1:0]  sqrt_data_in;

    logic                   sqrt_ready_out;
    logic                   sqrt_valid_out;
    logic [DATA_WIDTH-1:0]  sqrt_data_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    sqrt #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION)
    ) sqrt (
        .clk    (clk),
        .rst    (rst),

        .sqrt_ready_in  (sqrt_ready_in),
        .sqrt_valid_in  (sqrt_valid_in),
        .sqrt_data_in   (sqrt_data_in),

        .sqrt_ready_out (sqrt_ready_out),
        .sqrt_valid_out (sqrt_valid_out),
        .sqrt_data_out  (sqrt_data_out)
    );

    int unsigned num_inputs = 10000;

    mailbox mbx = new(num_inputs);

    bit valid;
    logic signed [DATA_WIDTH-1:0] rand_data;
    real rand_data_sqrt;                                                       

    bit valid_queue[$];  
    logic [DATA_WIDTH-1:0] rand_data_queue[$];      

    real rand_data_real;

    initial begin
        for (int i=0; i<num_inputs; i++) begin
            //valid = $urandom_range(1'b0, 1'b1);
            valid = 1'b1;
            rand_data = $urandom_range(0, (2**(DATA_WIDTH-1))-1);

            valid_queue.push_back(valid);
            rand_data_queue.push_back(rand_data);

            if (valid) begin
                rand_data_real = rand_data / $itor(2**FRACTION);
                rand_data_sqrt = $sqrt(rand_data_real);
                mbx.put(rand_data_sqrt);
            end
        end

        sqrt_ready_out = 1'b0;
        sqrt_valid_in = 1'b0;
        sqrt_data_in = {DATA_WIDTH{1'b0}};

        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            //sqrt_ready_out <= $urandom_range(1'b0, 1'b1);
            sqrt_ready_out <= 1'b1;
            if (sqrt_ready_in | ~sqrt_valid_in) begin
                sqrt_data_in <= rand_data_queue.pop_front();
                sqrt_valid_in <= valid_queue.pop_front();
            end
        end
        $display("test successful");
        $stop;
    end

    initial begin
        real mbx_received;
        real dat_scaled; 
        forever begin
            #(CLK_PERIOD);
            if (sqrt_valid_out && sqrt_ready_out) begin
                mbx.get(mbx_received);
                dat_scaled = sqrt_data_out / $itor(2**FRACTION);

                if (abs_real(dat_scaled - mbx_received) > 0.0125) begin
                    //mbx_scaled = mbx_received / $itor(2**FRACTION);
                    $display("discrepency between expected value: %f, and received value: %f", mbx_received, dat_scaled);
                    $stop;
                end
            end
        end
    end

    // function automatic logic [DATA_WIDTH-1:0] sqrt_func(
    //     input logic signed [DATA_WIDTH-1:0] rad   // radicand
    // );
    //     localparam ITER = (DATA_WIDTH+FRACTION) >> 1;  // iterations are half radicand+fbits width
    //     logic [DATA_WIDTH-1:0] x;          // radicand copy
    //     logic [DATA_WIDTH-1:0] q;          // intermediate root (quotient)
    //     logic [DATA_WIDTH+1:0] ac;         // accumulator (2 bits wider)
    //     logic [DATA_WIDTH+1:0] test_res;   // sign test result (2 bits wider)
        
    //     // Initialize variables
    //     q = '0;
    //     x = rad;
    //     ac = '0;
        
    //     for (int i = 0; i < ITER; i++) begin
    //         test_res = ac - {q, 2'b01};
    //         if (test_res[DATA_WIDTH+1] == 0) begin  // test_res ≥0? (check MSB)
    //             {ac, x} = {test_res[DATA_WIDTH-1:0], x, 2'b0};
    //             q = {q[DATA_WIDTH-2:0], 1'b1};
    //         end else begin
    //             {ac, x} = {ac[DATA_WIDTH-1:0], x, 2'b0};
    //             q = q << 1;
    //         end
    //     end
        
    //     return q;
    // endfunction

    function real abs_real(real value);
        abs_real = (value < 0.0) ? -value : value;
    endfunction
endmodule