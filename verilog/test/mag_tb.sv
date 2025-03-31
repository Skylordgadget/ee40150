`timescale 1ns / 1ns

`include "./../pkg/helper_pkg.sv"

module mag_tb();
    import helper_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 16;
    localparam FRACTION = 8;
    localparam PIPE_WIDTH = 4;

    logic clk;
    logic rst;

    logic                   mag_ready_in;
    logic                   mag_valid_in;
    logic [DATA_WIDTH-1:0]  mag_dataa_in;
    logic [DATA_WIDTH-1:0]  mag_datab_in;

    logic                   mag_ready_out;
    logic                   mag_valid_out;
    logic [DATA_WIDTH-1:0]  mag_data_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    mag #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) mag (
        .clk    (clk),
        .rst    (rst),

        .mag_ready_in  (mag_ready_in),
        .mag_valid_in  (mag_valid_in),
        .mag_dataa_in  (mag_dataa_in),
        .mag_datab_in  (mag_datab_in),

        .mag_ready_out (mag_ready_out),
        .mag_valid_out (mag_valid_out),
        .mag_data_out  (mag_data_out)
    );

    int unsigned num_inputs = 10000;

    mailbox mbx = new(num_inputs);

    bit valid;
    logic signed [DATA_WIDTH-1:0] rand_dataa;
    logic signed [DATA_WIDTH-1:0] rand_datab;
    real rand_dataa_real, rand_datab_real, rand_data_mag;                                   

    bit valid_queue[$];  
    logic [DATA_WIDTH-1:0] rand_dataa_queue[$];      
    logic [DATA_WIDTH-1:0] rand_datab_queue[$];    

    initial begin
        for (int i=0; i<num_inputs; i++) begin
            valid = $urandom_range(1'b0, 1'b1);
            //valid = 1'b1;
            rand_dataa = $urandom_range(0, 2**DATA_WIDTH);
            rand_datab = $urandom_range(0, 2**DATA_WIDTH);

            valid_queue.push_back(valid);
            rand_dataa_queue.push_back(rand_dataa);
            rand_datab_queue.push_back(rand_datab);

            if (valid) begin
                rand_dataa_real = rand_dataa / $itor(2**FRACTION);
                rand_datab_real = rand_datab / $itor(2**FRACTION);
                rand_data_mag = $sqrt(rand_dataa_real**2 + rand_datab_real**2);
                mbx.put(rand_data_mag);
            end
        end

        mag_ready_out = 1'b0;
        mag_valid_in = 1'b0;
        mag_dataa_in = {DATA_WIDTH{1'b0}};
        mag_datab_in = {DATA_WIDTH{1'b0}};

        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            mag_ready_out <= $urandom_range(1'b0, 1'b1);
            //mag_ready_out <= 1'b1;
            if (mag_ready_in | ~mag_valid_in) begin
                mag_dataa_in <= rand_dataa_queue.pop_front();
                mag_datab_in <= rand_datab_queue.pop_front();
                mag_valid_in <= valid_queue.pop_front();
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
            if (mag_valid_out && mag_ready_out) begin
                mbx.get(mbx_received);
                dat_scaled = mag_data_out / $itor(2**FRACTION);

                if (abs_real(dat_scaled - mbx_received) > 0.0125) begin
                    //mbx_scaled = mbx_received / $itor(2**FRACTION);
                    $display("discrepency between expected value: %f, and received value: %f", mbx_received, dat_scaled);
                    $stop;
                end
            end
        end
    end

    // function automatic logic [DATA_WIDTH-1:0] mag_func(
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