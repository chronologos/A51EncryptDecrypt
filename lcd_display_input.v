module lcd_display_input(clk, lcd_rs, lcd_rw, lcd_e, lcd_4, lcd_5, lcd_6, lcd_7);
  input clk;
  output lcd_rs;
  output lcd_rw;
  output lcd_7;
  output lcd_6;
  output lcd_5;
  output lcd_4;
  output lcd_e;
  wire[223:0] regin, regout;
  assign regin = 224'h43616c6c206d65206973686d61656c20202020202020202020202020;
  yt61_reg #(224) myReg(regin, {224{1'b1}}, {224{1'b1}}, regout, 1'b1, clk);
  lcd_display my_display(clk, lcd_rs, lcd_rw, lcd_e, lcd_4, lcd_5, lcd_6, lcd_7, regout);
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
