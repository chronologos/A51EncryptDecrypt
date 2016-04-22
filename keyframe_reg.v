module keyframe_reg(ps2data_in, keyindex, keyframe_out, write_enable, clk, reset);
  input [3:0] ps2data_in;
  input [3:0] keyindex;
	input write_enable, clk, reset;
  output [85:0] keyframe_out;

  wire [15:0] ps2keyCtrl;
  wire [63:0] ps2key64, ps2Ctrl64;

  assign ps2keyCtrl = 1 << keyindex;

  assign ps2key64 = {16{ps2data_in}};

  assign ps2Ctrl64 = {		{4{ps2keyCtrl[15]}}, {4{ps2keyCtrl[14]}}, {4{ps2keyCtrl[13]}}, {4{ps2keyCtrl[12]}},
                      {4{ps2keyCtrl[11]}}, {4{ps2keyCtrl[10]}}, {4{ps2keyCtrl[9]}}, {4{ps2keyCtrl[8]}},{4{ps2keyCtrl[7]}}, {4{ps2keyCtrl[6]}}, {4{ps2keyCtrl[5]}}, {4{ps2keyCtrl[4]}},
                      {4{ps2keyCtrl[3]}}, {4{ps2keyCtrl[2]}}, {4{ps2keyCtrl[1]}}, {4{ps2keyCtrl[0]}}			};

  assign keyframe_out[21:0] = 22'h000134; //hard-coded frame

  genvar c;
  generate
    for (c = 0; c < 64; c = c + 1) begin: loopDFFs
      DFFE my_dff(.d(ps2key64[c]),.clrn(~reset),.prn(1'b1),.clk(clk),.q(keyframe_out[c+22]),.ena(write_enable && ps2Ctrl64[c]));
    end
  endgenerate

endmodule
