`timescale 10 ns / 1 ns
module giantMuxtb();
    reg[223:0] in;
    reg [4:0] index;
    wire[7:0] out;
    giantMux DUT(in,index,out);
    initial
    begin
        in = 224'b111111110000000011111111;
        index = 5'b0;
        #100;
        index = 5'b1;
        #100;
        $stop;
    end
 endmodule
