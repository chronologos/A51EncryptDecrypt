module giantMux(in,index,out);
	input [223:0] in;
	input [4:0] index; //2^5 = 32 > 28 = 224/8
	wire [31:0] decoder_out;
	output [7:0] out;
	my_decoder giantMuxDecoder(.decoder_select(index), .decoder_out(decoder_out), .decoder_enable(1'b1));
	genvar c;
	generate
		for (c = 0; c < 28; c = c + 1) begin: loopTri
			my_tri #(8) triX(.in(in[(c*8)+7:c*8]),.enable(decoder_out[c]),.out(out));
		end
	endgenerate
endmodule
