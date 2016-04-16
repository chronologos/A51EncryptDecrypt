module lcd_display (clk, lcd_rs, lcd_rw, lcd_e, lcd_4, lcd_5, lcd_6, lcd_7, regout);
  //http://www.ijtra.com/view/a-novel-approach-for-displaying-data-on-lcd-using-fpga.pdf
  parameter n = 27;
  parameter k = 17;
  // (* LOC="E12" *) input clk; // synthesis attribute PERIOD clk "100.0 MHz"
  input clk;
  input[223:0] regout;
  reg [n-1:0] count=0;
  reg lcd_busy=1;
  reg lcd_stb;
  reg [5:0] lcd_code;
  reg [6:0] lcd_stuff;
  output reg lcd_rs;
  output reg lcd_rw;
  output reg lcd_7;
  output reg lcd_6;
  output reg lcd_5;
  output reg lcd_4;
  output reg lcd_e;
  always @ (posedge clk) begin
    count <= count + 1;
    case (count[k+7:k+2])
      0: lcd_code <= 6'b000010; // function set
      1: lcd_code <= 6'b000010;
      2: lcd_code <= 6'b001100;
      3: lcd_code <= 6'b000000; // display on/off control
      4: lcd_code <= 6'b001100;
      5: lcd_code <= 6'b000000; // display clear
      6: lcd_code <= 6'b000001;
      7: lcd_code <= 6'b000000; // entry mode set
      8: lcd_code <= 6'b000110;
      9: lcd_code <= {2'h2, regout[223:220]}; // 1
      10: lcd_code <= {2'h2, regout[219:216]};
      11: lcd_code <= {2'h2, regout[215:212]}; // 2
      12: lcd_code <= {2'h2, regout[211:208]};
      13: lcd_code <= {2'h2, regout[207:204]}; // 3
      14: lcd_code <= {2'h2, regout[203:200]};
      15: lcd_code <= {2'h2, regout[199:196]}; // 4
      16: lcd_code <= {2'h2, regout[195:192]};
      17: lcd_code <= {2'h2, regout[191:188]}; // 5
      18: lcd_code <= {2'h2, regout[187:184]};
      19: lcd_code <= {2'h2, regout[183:180]}; // 6
      20: lcd_code <= {2'h2, regout[179:176]};
      21: lcd_code <= {2'h2, regout[175:172]}; // 7
      22: lcd_code <= {2'h2, regout[171:168]};
      23: lcd_code <= {2'h2, regout[167:164]}; // 8
      24: lcd_code <= {2'h2, regout[163:160]};
      25: lcd_code <= {2'h2, regout[159:156]}; // 9
      26: lcd_code <= {2'h2, regout[155:152]};
      27: lcd_code <= {2'h2, regout[151:148]}; // 10
      28: lcd_code <= {2'h2, regout[147:144]};
      29: lcd_code <= {2'h2, regout[143:140]}; // 11
      30: lcd_code <= {2'h2, regout[139:136]};
      31: lcd_code <= {2'h2, regout[135:132]}; // 12
      32: lcd_code <= {2'h2, regout[131:128]};
      default: lcd_code <= 6'b010000;
    endcase
    if (lcd_rw)
      lcd_busy <= 0;
      lcd_stb <= ^count[k+1:k+0] & ~lcd_rw & lcd_busy; // clkrate / 2^(k+2);
      lcd_stuff <= {lcd_stb,lcd_code};
      {lcd_e,lcd_rs,lcd_rw,lcd_7,lcd_6,lcd_5,lcd_4} <=
      lcd_stuff;
    end
endmodule
