module scantoascii(in, out);
  input [7:0] in;
  output [7:0] out;
  reg [7:0] out;

  always @(in)
  case (in)
    8'h15: out=8'h71; //q
    8'h1D: out=8'h77; //w
    8'h24: out=8'h65; //e
    default: out=in;
  endcase

endmodule
