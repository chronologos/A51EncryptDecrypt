`timescale 10 ns / 1 ns
module a51_tb();

    // inputs to the DUT are reg type
    reg clock, reset, enterToKeyNotData, startKeyStreamGen, ps2_
    wire[18:0] out19;
    wire[21:0] out22;
    wire[22:0] out23;
    wire [85:0] testout;
    wire out;
    module a51(clock,reset,enterToKeyNotData, startKeyStreamGen, ps2_clock, ps2_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon, lcd_data);

    initial
    begin
        $display($time, " << Starting the Simulation >>");
        clock = 1'b0;    // at time 0
        reset = 1'b1;
        #10;
        reset = 1'b0;
        #500;
        $stop;
    end
    // Clock generator
    always
      #1 clock = ~clock;    // toggle
 endmodule
