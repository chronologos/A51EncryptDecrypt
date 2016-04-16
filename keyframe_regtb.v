`timescale 10 ns / 1 ns
module keyframe_regtb();

    // inputs to the DUT are reg type
    reg[7:0] ps2data_in;
    reg[2:0] index;
    wire[85:0] datastore_out;
    reg write_enable, clk, reset;

    keyframe_reg DUT (ps2data_in, index, datastore_out, write_enable, clk, reset);

    initial
    begin
        $display($time, " << Starting the Simulation >>");
        clk = 1'b0;    // at time 0
        reset = 1'b1;
        write_enable = 1'b1;
        ps2data_in = 8'b11111111;
        index = 3'b111;
        #10;
        reset = 1'b0;
        #50;
        index = 3'b110;
        #50;
        index = 3'b101;
        #50;
        $stop;
    end
    // Clock generator
    always
      #1 clk = ~clk;    // toggle
 endmodule
