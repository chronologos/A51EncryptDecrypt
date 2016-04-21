module key_counter (clock, reset, index, enterToKey, keyPress);
  input clock, reset, enterToKey, keyPress;
  output [2:0] index;
  reg [2:0] tmp;

  always @(posedge reset or negedge keyPress) begin
      if (reset) begin
			tmp <= 3'd0;
      end else begin
			if (enterToKey) begin
				tmp <= tmp + 3'd1;
			end
		end
  end
  assign index = tmp;
endmodule
