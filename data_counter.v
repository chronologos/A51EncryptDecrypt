module data_counter (clock, reset, index, enterToData, keyPress, backspace);
  input clock, reset, enterToData, keyPress, backspace;
  output [4:0] index;
  reg [4:0] tmp;

  always @(posedge reset or negedge keyPress) begin
      if (reset) begin
			tmp <= 5'd0;
      end else begin
			if (enterToData) begin
				if(backspace) begin
					tmp <= tmp - 5'd1;
				end else begin
					tmp <= tmp + 5'd1;
				end
			end
		end
  end
  assign index = tmp;
endmodule
