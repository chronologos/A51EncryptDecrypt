module scantoascii(in, out);
  input [7:0] in;
  output [7:0] out;
  reg [7:0] out;

  always @(in)
  case (in)
    8'h45: out=8'h30; //scan code for 0 key on keyboard to ascii value of 0.
    8'h16: out=8'h31; //1
    8'h1E: out=8'h32; //2
    8'h26: out=8'h33; //3
    8'h25: out=8'h34; //4
    8'h2E: out=8'h35; //5
    8'h36: out=8'h36; //6
    8'h3D: out=8'h37; //7
    8'h3E: out=8'h38; //8
    8'h46: out=8'h39; //9
    8'h1C: out=8'h41; //A
    8'h32: out=8'h42; //B
    8'h21: out=8'h43; //C
    8'h23: out=8'h44; //D
    8'h24: out=8'h45; //E
    8'h2B: out=8'h46; //F
    default: out=8'h78; //x = error
  endcase

endmodule
