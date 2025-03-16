`timescale 1ns / 1ns

`include "./../pkg/helper_pkg.sv"
`include "./../pkg/fft_pkg.sv"


module fft_stage_tb();
    import helper_pkg::*;
    import fft_pkg::*;
    
    localparam CLK_PERIOD = 10;

    localparam DATA_WIDTH   = 16;
    localparam FRACTION     = 11;
    localparam FFT_POINTS   = 8;
    localparam BUTTERFLIES  = 4;
    localparam PIPE_WIDTH   = 4;
    localparam FFT_POINTS_W = clog2(FFT_POINTS);
    localparam TWIDDLES = FFT_POINTS / 2;
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

    typedef complex complexp_t [FFT_POINTS];

    logic clk;
    logic rst;

    logic   fft_stage_ready_in;
    logic   fft_stage_valid_in;
    complex fft_stage_data_in   [0:FFT_POINTS-1];

    logic   fft_stage_ready_out;
    logic   fft_stage_valid_out;
    complex fft_stage_data_out  [0:FFT_POINTS-1];

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    fft_stage #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) fft_stage (
        .clk    (clk),
        .rst    (rst),

        .fft_stage_ready_in     (fft_stage_ready_in),          
        .fft_stage_valid_in     (fft_stage_valid_in),          
        .fft_stage_data_in      (fft_stage_data_in),

        .fft_stage_ready_out    (fft_stage_ready_out),
        .fft_stage_valid_out    (fft_stage_valid_out),
        .fft_stage_data_out     (fft_stage_data_out)
    );

    int unsigned num_inputs = 1000;

    mailbox mbx = new(num_inputs);

    bit valid;
    bit ready;

    bit valid_queue[$];                                                         
    complexp_t rand_data_queue[$];      
    complexp_t rand_data;
    complexp_t rand_data_ff;

    initial begin
        for (int i=0; i<num_inputs; i++) begin
            valid = 1'b1;
            //valid = $urandom_range(1'b0, 1'b1);
            for (int j=0; j<FFT_POINTS; j++) begin
                rand_data[j].re = $urandom_range(0, 10);
                rand_data[j].im = 'b0;
            end

            valid_queue.push_back(valid);
            rand_data_queue.push_back(rand_data);

            if (valid) begin
                rand_data_ff = rand_data;
                fft_radix2_dit(rand_data_ff, fft_stage.twiddle8); // TODO replace twiddle8 with generic
                mbx.put(rand_data_ff);
            end
        end

        fft_stage_ready_out = 1'b0;
        fft_stage_valid_in = 1'b0;
        for (int i=0; i<FFT_POINTS; i++) begin
            fft_stage_data_in[i] = 'b0;
        end
        
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);
            
            //fft_stage_ready_out <= $urandom_range(1'b0, 1'b1);
            fft_stage_ready_out <= 1'b1;
            if (fft_stage_ready_in | ~fft_stage_valid_in) begin
                fft_stage_valid_in <= valid_queue.pop_front();
                fft_stage_data_in <= rand_data_queue.pop_front();
            end
        end

        // fft_stage_data_in <= rand_data_queue.pop_front();
        // for (int i=0; i<num_inputs; i++) begin
        //     #(CLK_PERIOD);
            
        //     // //fft_stage_ready_out <= $urandom_range(1'b0, 1'b1);
        //     fft_stage_ready_out <= 1'b1;
        //     // if (fft_stage_ready_in | ~fft_stage_valid_in) begin
        //     //     //fft_stage_valid_in <= valid_queue.pop_front();
        //     fft_stage_valid_in <= 1'b1;
        //     //     fft_stage_data_in <= rand_data_queue.pop_front();
        //     // end
        // end

        $display("test successful");
        $stop;
    end

    initial begin
        complexp_t mbx_received;
        int sum;
        forever begin
            #(CLK_PERIOD);
            if (fft_stage_valid_out && fft_stage_ready_out) begin
                mbx.get(mbx_received);
                if (mbx_received != fft_stage_data_out) begin
                    $display("discrepency between expected value: %p, and received value: %p", mbx_received, fft_stage_data_out);
                    $stop;
                end
            end
        end
    end

    function void fft_radix2_dit(
        inout complexp_t data,
        input complex twiddles[]
    );
        int i, j, k, m, stage, half_N;
        complex_double temp;
        
        // Bit-reversal permutation
        int reversed[FFT_POINTS];
        reversed = '{default: 0};
        for (i = 0; i < FFT_POINTS; i++) begin
            reversed[i] = reversebits(i)[31-:FFT_POINTS_W];
        end
        
        $display("data before fft: %p", data);

        // FFT computation
        for (stage = 1; stage <= FFT_POINTS_W; stage++) begin
            half_N = 1 << (stage - 1);
            for (k = 0; k < FFT_POINTS; k += (half_N * 2)) begin
                for (m = 0; m < half_N; m++) begin
                    i = k + m;
                    j = i + half_N;
                    
                    // Butterfly operation
                    temp.re = twiddles[m].re * data[j].re - twiddles[m].im * data[j].im;
                    temp.im = twiddles[m].re * data[j].im + twiddles[m].im * data[j].re;
                    
                    data[j].re = data[i].re - temp.re[MULT_OUT_MSB-:DATA_WIDTH];
                    data[j].im = data[i].im - temp.im[MULT_OUT_MSB-:DATA_WIDTH];
                    
                    data[i].re = data[i].re + temp.re[MULT_OUT_MSB-:DATA_WIDTH];
                    data[i].im = data[i].im + temp.im[MULT_OUT_MSB-:DATA_WIDTH];
                end
            end
        end
        $display("data after fft: %p", data);
    endfunction

endmodule