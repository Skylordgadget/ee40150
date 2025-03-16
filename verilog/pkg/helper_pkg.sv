// synopsys translate_off
`timescale 1ns / 1ns
// synopsys translate_on


package helper_pkg;
    function integer clog2;
        input [31:0] value;
        integer i;
        begin
            clog2 = 32;
            for(i=31; i>0; i--) begin
                if (2**i >= value) begin
                    clog2 = i;
                end
            end
        end
    endfunction
endpackage