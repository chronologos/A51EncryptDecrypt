module data_counter (clock, reset, index, enterToData, keyPress);
input clock, reset, enterToData, keyPress;
output [4:0] index;
reg [4:0] tmp;

	always @(posedge clock) begin
		if (reset) begin
			tmp = 5'd0
		end
	end 
	
  always @(posedge keyPress) begin
      if (enterToData) begin
			tmp = tmp + 5'd1;
      end
  end
  assign index = tmp;
endmodule
