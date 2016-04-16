`timescale 10 ns / 1 ns
module datastore_regtb();

    // inputs to the DUT are reg type
    reg[7:0] ps2data_in;
    reg[4:0] index;
    wire[223:0] datastore_out;
    reg write_enable, clk, reset;

    datastore_reg DUT (ps2data_in, index, datastore_out, write_enable, clk, reset);

    initial
    begin
        $display($time, " << Starting the Simulation >>");
        clk = 1'b0;    // at time 0
        reset = 1'b1;
        write_enable = 1'b1;
        ps2data_in = 8'b10101010;
        index = 5'b00001;
        #10;
        reset = 1'b0;
        #50;
        index = 5'b00011;
        #50;
        index = 5'b00111;
        #50;
        $stop;
    end
    // Clock generator
    always
      #1 clk = ~clk;    // toggle
 endmodule
