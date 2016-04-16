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
  lcd mylcd(clock, 1'b0, 1'b1, data_to_lcd, lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);
  yt61_reg #(8) myreg(ps2_out,{8{1'b1}},{8{1'b1}},data_to_lcd,1'b1,clock);

endmodule

module yt61_reg(reg_d,reg_prn,reg_clrn,reg_f,write_enable,clk);
	parameter DATA_WIDTH = 32;
	input [DATA_WIDTH-1:0] reg_d, reg_clrn, reg_prn;
	input write_enable,clk;
	output [DATA_WIDTH-1:0]reg_f;
	genvar c;
	generate
		for (c = 0; c<=(DATA_WIDTH-1); c = c + 1) begin: loopDFFs
			DFFE my_dff(.d(reg_d[c]),.clrn(reg_clrn[c]),.prn(reg_prn[c]),.clk(clk),.q(reg_f[c]),.ena(write_enable));
		end
	endgenerate
endmodule
