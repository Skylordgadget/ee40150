// synopsys translate_off
`timescale 1ns / 1ns
// synopsys translate_on

package fft_pkg;
    function integer reversebits;
        input [31:0] value;
        integer i;
        begin
            for (i=0; i<32; i++) begin
                reversebits[i] = value[31-i];
            end
        end
    endfunction
endpackage