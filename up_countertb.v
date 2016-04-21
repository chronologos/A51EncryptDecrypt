`timescale 10 ns / 1 ns
module up_countertb();
    // inputs to the DUT are reg type
    reg clk;
    reg clr;
    reg ENABLE;
    wire Q, STAGEONE, STAGETWO, STAGETHREE, OUTPUTSTAGE, DONE;
    up_counter DUT(clk, clr, Q, ENABLE, STAGEONE, STAGETWO, STAGETHREE, OUTPUTSTAGE, DONE);

    initial
    begin
        $display($time, " << Starting the Simulation >>");
        clk = 1'b0;    // at time 0
        clr = 1'b1;

        ENABLE = 1'b0;

        #100;
        ENABLE = 1'b1;
        clr = 1'b0;
        #3000;
        $stop;
    end
    // Clock generator
    always
      #10 clk = ~clk;    // toggle
 endmodule
