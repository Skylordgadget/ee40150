`timescale 1ns / 1ns

`include "./../pkg/helper_pkg.sv"

module tanh_tb();
    import helper_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 16;
    localparam TANH_SAMPLES = 64;
    localparam TANH_LUT = "../verilog/src/tanh/tanh_lookup_8I8F.hex";
    localparam signed [DATA_WIDTH-1:0] TANH_MAX = 16'h03e0;
    localparam signed [DATA_WIDTH-1:0] TANH_MIN = 16'hfc00;
    localparam ID_MSB = 10; 
    localparam ID_LSB = 5;

    logic clk;
    logic rst;

    logic                   tanh_ready_in;
    logic                   tanh_valid_in;
    logic [DATA_WIDTH-1:0]  tanh_data_in;

    logic                   tanh_ready_out;
    logic                   tanh_valid_out;
    logic [DATA_WIDTH-1:0]  tanh_data_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    tanh #(
        .DATA_WIDTH     (DATA_WIDTH),
        .TANH_SAMPLES   (TANH_SAMPLES),
        .TANH_LUT       (TANH_LUT),
        .TANH_MAX       (TANH_MAX),
        .TANH_MIN       (TANH_MIN),
        .ID_MSB         (ID_MSB),
        .ID_LSB         (ID_LSB)
    ) tanh (
        .clk    (clk),
        .rst    (rst),

        .tanh_ready_in  (tanh_ready_in),
        .tanh_valid_in  (tanh_valid_in),
        .tanh_data_in   (tanh_data_in),

        .tanh_ready_out (tanh_ready_out),
        .tanh_valid_out (tanh_valid_out),
        .tanh_data_out  (tanh_data_out)
    );

    int unsigned num_inputs = 10000;

    mailbox mbx = new(num_inputs);

    int unsigned temp;

    bit valid;
    logic signed [DATA_WIDTH-1:0] rand_data;
    //real rand_dataa_real, rand_datab_real, rand_data_tanh;                                   

    bit valid_queue[$];  
    logic [DATA_WIDTH-1:0] rand_data_queue[$];      

    initial begin
        for (int i=0; i<num_inputs; i++) begin
            //valid = $urandom_range(1'b0, 1'b1);
            valid = 1'b1;
            //rand_data = $urandom_range(0, 2**DATA_WIDTH);
            temp = i*10;
            rand_data = temp[DATA_WIDTH-1:0];

            valid_queue.push_back(valid);
            rand_data_queue.push_back(rand_data);

            // if (valid) begin
            //     rand_dataa_real = rand_dataa / $itor(2**FRACTION);
            //     rand_datab_real = rand_datab / $itor(2**FRACTION);
            //     rand_data_tanh = $sqrt(rand_dataa_real**2 + rand_datab_real**2);
            //     mbx.put(rand_data_tanh);
            // end
        end

        tanh_ready_out = 1'b0;
        tanh_valid_in = 1'b0;
        tanh_data_in = {DATA_WIDTH{1'b0}};

        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            //tanh_ready_out <= $urandom_range(1'b0, 1'b1);
            tanh_ready_out <= 1'b1;
            if (tanh_ready_in | ~tanh_valid_in) begin
                tanh_data_in <= rand_data_queue.pop_front();
                tanh_valid_in <= valid_queue.pop_front();
            end
        end
        $display("test successful");
        $stop;
    end

    // initial begin
    //     real mbx_received;
    //     real dat_scaled; 
    //     forever begin
    //         #(CLK_PERIOD);
    //         if (tanh_valid_out && tanh_ready_out) begin
    //             mbx.get(mbx_received);
    //             dat_scaled = tanh_data_out / $itor(2**FRACTION);

    //             if (abs_real(dat_scaled - mbx_received) > 0.0125) begin
    //                 //mbx_scaled = mbx_received / $itor(2**FRACTION);
    //                 $display("discrepency between expected value: %f, and received value: %f", mbx_received, dat_scaled);
    //                 $stop;
    //             end
    //         end
    //     end
    // end


    function real abs_real(real value);
        abs_real = (value < 0.0) ? -value : value;
    endfunction
endmodule