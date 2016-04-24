module key_counter (clock, reset, index, enterToKey, keyPress, backspace);
  input clock, reset, enterToKey, keyPress, backspace;
  output [3:0] index;
  reg [3:0] tmp;

  always @(posedge reset or negedge keyPress) begin
      if (reset) begin
			tmp <= 4'd0;
      end else begin
			if (enterToKey) begin
				if(backspace) begin
					tmp <= tmp - 4'd1;
				end else begin
				   tmp <= tmp + 4'd1;
				end
			end
		end		
  end
  assign index = tmp;
endmodule
