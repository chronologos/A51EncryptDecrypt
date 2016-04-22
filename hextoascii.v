module hextoascii(in, out);
  input [3:0] in;
  output [7:0] out;
  reg [7:0] out;

  always @(in)
  case (in)
    4'h0: out=8'h30; //0
    4'h1: out=8'h31; //1
    4'h2: out=8'h32; //2
    4'h3: out=8'h33; //3
    4'h4: out=8'h34; //4
    4'h5: out=8'h35; //5
    4'h6: out=8'h36; //6
    4'h7: out=8'h37; //7
    4'h8: out=8'h38; //8
    4'h9: out=8'h39; //9
    4'hA: out=8'h41; //A
    4'hB: out=8'h42; //B
    4'hC: out=8'h43; //C
    4'hD: out=8'h44; //D
    4'hE: out=8'h45; //E
    4'hF: out=8'h46; //F
  endcase

endmodule
