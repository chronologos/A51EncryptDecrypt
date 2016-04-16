`timescale 10 ns / 1 ns
module up_countertb();
    // inputs to the DUT are reg type
    reg clk;
    reg clr;
    wire Q, STAGEONE, STAGETWO, STAGETHREE, OUTPUTSTAGE;
    up_counter DUT(clk, clr, Q, STAGEONE, STAGETWO, STAGETHREE, OUTPUTSTAGE);

    initial
    begin
        $display($time, " << Starting the Simulation >>");
        clk = 1'b0;    // at time 0
        clr = 1'b1;
        #100;
        clr = 1'b0;
        #3000;
        $stop;
    end
    // Clock generator
    always
      #10 clk = ~clk;    // toggle
 endmodule
