module scantohex(in, out);
  input [7:0] in;
  output [3:0] out;
  reg [3:0] out;

  always @(in)
  case (in)
    8'h45: out=4'h0; //scan code for 0 key on keyboard to hex 0
    8'h16: out=4'h1; //1
    8'h1E: out=4'h2; //2
    8'h26: out=4'h3; //3
    8'h25: out=4'h4; //4
    8'h2E: out=4'h5; //5
    8'h36: out=4'h6; //6
    8'h3D: out=4'h7; //7
    8'h3E: out=4'h8; //8
    8'h46: out=4'h9; //9
    8'h1C: out=4'hA; //A
    8'h32: out=4'hB; //B
    8'h21: out=4'hC; //C
    8'h23: out=4'hD; //D
    8'h24: out=4'hE; //E
    8'h2B: out=4'hF; //F
    default: out=4'h0; //silent error
  endcase

endmodule
