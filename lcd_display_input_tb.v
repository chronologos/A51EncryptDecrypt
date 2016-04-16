`timescale 10 ns / 1 ns
module lcd_display_input_tb();
    // inputs to the DUT are reg type
    reg clock;
    wire wirerandom, wirerandom2, wirerandom3, wirerandom4, wirerandom5, wirerandom6, wirerandom7;

    lcd_display_input DUT(clock, wirerandom, wirerandom2, wirerandom3, wirerandom4, wirerandom5, wirerandom6, wirerandom7);

    initial
    begin
        $display($time, " << Starting the Simulation >>");
        clock = 1'b0;    // at time 0
        #500;
    end
    // Clock generator
    always

         #1     clock = ~clock;    // toggle
 endmodule
