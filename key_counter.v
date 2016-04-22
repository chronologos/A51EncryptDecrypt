module key_counter (clock, reset, index, enterToKey, keyPress);
  input clock, reset, enterToKey, keyPress;
  output [3:0] index;
  reg [3:0] tmp;

  always @(posedge reset or negedge keyPress) begin
      if (reset) begin
			tmp <= 4'd0;
      end else begin
			if (enterToKey) begin
				tmp <= tmp + 4'd1;
			end
		end
  end
  assign index = tmp;
endmodule
