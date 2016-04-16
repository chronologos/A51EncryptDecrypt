module up_counter (C, CLR, Q, STAGEONE, STAGETWO, STAGETHREE, OUTPUTSTAGE);
input C, CLR;
output [9:0] Q;
output reg STAGEONE, STAGETWO, STAGETHREE,OUTPUTSTAGE;
reg [9:0] tmp;

  always @(posedge C) begin
      if (CLR) begin
        tmp = 10'd0;
      end else begin
			  tmp = tmp + 10'd1;
			  if (tmp <= 10'd64) begin
					STAGEONE = 1;
					STAGETWO = 0;
					STAGETHREE = 0;
          OUTPUTSTAGE = 0;
				end else if (tmp <= 10'd86 && tmp>10'd64) begin
					STAGEONE = 0;
					STAGETWO = 1;
					STAGETHREE = 0;
          OUTPUTSTAGE = 0;
				end else if (tmp > 10'd86 && tmp<=10'd186) begin
					STAGEONE = 0;
					STAGETWO = 0;
					STAGETHREE = 1;
          OUTPUTSTAGE = 0;
			  end else begin
					STAGEONE = 0;
					STAGETWO = 0;
					STAGETHREE = 0;
          OUTPUTSTAGE = 1;
			  end
      end

  end
  assign Q = tmp;
endmodule
