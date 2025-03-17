`timescale 1ns / 1ns

`include "./../pkg/helper_pkg.sv"
`include "./../pkg/fft_pkg.sv"


module fft_tb();
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

    logic                       fft_ready_in;
    logic                       fft_valid_in;
    logic   [DATA_WIDTH-1:0]    fft_data_in;

    logic                       fft_ready_out;
    logic                       fft_valid_out;
    complex                     fft_data_out    [0:FFT_POINTS-1];

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    fft #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACTION   (FRACTION),
        .FFT_POINTS (FFT_POINTS),
        .BUTTERFLIES(BUTTERFLIES),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) fft (
        .clk    (clk),
        .rst    (rst),

        .fft_ready_in     (fft_ready_in),          
        .fft_valid_in     (fft_valid_in),          
        .fft_data_in      (fft_data_in),

        .fft_ready_out    (fft_ready_out),
        .fft_valid_out    (fft_valid_out),
        .fft_data_out     (fft_data_out)
    );

    int unsigned num_inputs = 10000;

    mailbox mbx = new(num_inputs);

    bit valid;
    bit ready;
    int unsigned valid_cnt = 0;
    bit valid_queue[$];                                                         
    complex rand_data_queue[$];
    logic [DATA_WIDTH-1:0] rand_data;   
    complexp_t rand_data_p;
    complexp_t rand_data_p_fft;

    initial begin
        for (int i=0; i<num_inputs; i++) begin
            //valid = $urandom_range(1'b0, 1'b1);
            valid = 1'b1;
            rand_data = 'b0;
            rand_data[DATA_WIDTH-1-:INTEGER_BITS] = $urandom_range(0, 5);
            
            valid_queue.push_back(valid);
            rand_data_queue.push_back(rand_data);

            if (valid) begin
                rand_data_p[valid_cnt] = {rand_data, {DATA_WIDTH{1'b0}}};
                valid_cnt++;
            end

            if (valid_cnt == FFT_POINTS) begin
                valid_cnt = 0;
                rand_data_p_fft = rand_data_p;
                fft_radix2_dit(rand_data_p_fft, fft.fft_stage.twiddles); 
                mbx.put(rand_data_p_fft);
                //$display("put %p in the mailbox", rand_data_p_fft);
            end
        end

        fft_ready_out = 1'b0;
        fft_valid_in = 1'b0;
        fft_data_in = 'b0;
        
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);
            
            //fft_ready_out <= $urandom_range(1'b0, 1'b1);
            fft_ready_out <= 1'b1;
            if (fft_ready_in | ~fft_valid_in) begin
                fft_valid_in <= valid_queue.pop_front();
                fft_data_in <= rand_data_queue.pop_front();
            end
        end

        // fft_data_in <= rand_data_p_queue.pop_front();
        // for (int i=0; i<num_inputs; i++) begin
        //     #(CLK_PERIOD);
            
        //     // //fft_ready_out <= $urandom_range(1'b0, 1'b1);
        //     fft_ready_out <= 1'b1;
        //     // if (fft_ready_in | ~fft_valid_in) begin
        //     //     //fft_valid_in <= valid_queue.pop_front();
        //     fft_valid_in <= 1'b1;
        //     //     fft_data_in <= rand_data_p_queue.pop_front();
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
            if (fft_valid_out && fft_ready_out) begin
                mbx.get(mbx_received);
                if (mbx_received != fft_data_out) begin
                    $display("discrepency between expected (e) value and received (r) value\n(e) %p\n(r) %p", mbx_received, fft_data_out);
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
        complex data_temp;
        int rev;
        int twiddle_idx;
        
        // Bit-reversal permutation
        int reversed[FFT_POINTS];
        reversed = '{default: 0};

        for (i = 0; i < FFT_POINTS; i++) begin
            rev = 0;
            for (int b = 0; b < FFT_POINTS_W; b++) begin
                rev = (rev << 1) | ((i >> b) & 1);
            end

            reversed[i] = rev;

            if (rev > i) begin // Only swap if rev > i to avoid double swap
                data_temp = data[i];
                data[i] = data[rev];
                data[rev] = data_temp;
            end
        end

        // FFT computation
        for (stage = 1; stage <= FFT_POINTS_W; stage++) begin
            half_N = 1 << (stage - 1);
            for (k = 0; k < FFT_POINTS; k += (half_N * 2)) begin
                for (m = 0; m < half_N; m++) begin
                    i = k + m;
                    j = i + half_N;
                    //$display("stage %d, half_N %d, k %d, m %d, i %d, j %d", stage, half_N, k, m, i, j);

                    // Butterfly operation
                    twiddle_idx = m * (FFT_POINTS >> stage);
                    temp.re = (twiddles[twiddle_idx].re * data[j].re) - (twiddles[twiddle_idx].im * data[j].im);
                    temp.im = (twiddles[twiddle_idx].re * data[j].im) + (twiddles[twiddle_idx].im * data[j].re);
                    
                    data[j].re = data[i].re - temp.re[MULT_OUT_MSB-:DATA_WIDTH];
                    data[j].im = data[i].im - temp.im[MULT_OUT_MSB-:DATA_WIDTH];
                    
                    data[i].re = data[i].re + temp.re[MULT_OUT_MSB-:DATA_WIDTH];
                    data[i].im = data[i].im + temp.im[MULT_OUT_MSB-:DATA_WIDTH];
                end
            end
        end
    endfunction

endmodule