module giantMux(in,index,out);
	input [127:0] in;
	input [4:0] index; //128/4 = 32
	wire [31:0] decoder_out;
	output [3:0] out;
	my_decoder giantMuxDecoder(.decoder_select(index), .decoder_out(decoder_out), .decoder_enable(1'b1));
	genvar c;
	generate
		for (c = 0; c < 32; c = c + 1) begin: loopTri
			my_tri #(4) triX(.in(in[(c*4)+3:c*4]),.enable(decoder_out[c]),.out(out));
		end
	endgenerate
endmodule
