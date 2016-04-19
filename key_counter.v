module key_counter (clock, reset, index, enterToKey, keyPress);
input clock, reset, enterToKey, keyPress;
output [2:0] index;
reg [2:0] tmp;

	always @(posedge clock) begin
		if (reset) begin
			tmp = 3'd0
		end
	end 

  always @(posedge keyPress) begin
      if (enterToKey) begin
			tmp = tmp + 3'd1;
      end
  end
  assign index = tmp;
endmodule
