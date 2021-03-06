module ps2lcdinterface(clock,ps2_clock,ps2_data, lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);
  input clock;
	input ps2_clock, ps2_data;

  wire[7:0] data_to_lcd;
	wire [7:0] ps2_key_data;
	wire ps2_key_pressed;
	wire [7:0]	ps2_out;

  output lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon;
  output [7:0] lcd_data;

  PS2_Interface myps2(clock, 1'b1, ps2_clock, ps2_data, ps2_key_data, ps2_key_pressed, ps2_out);
  lcd mylcd(clock, 1'b0, ps2_key_pressed, data_to_lcd, lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);
  yt61_reg #(8) myreg(ps2_out,{8{1'b1}},{8{1'b1}},data_to_lcd,1'b1,clock);

endmodule