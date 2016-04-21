module a51counter (C, CLR, Q, ENABLE, STAGEONE, STAGETWO, STAGETHREE, OUTPUTSTAGE, DONE);
input C, CLR, ENABLE;
output [9:0] Q;
output reg STAGEONE, STAGETWO, STAGETHREE,OUTPUTSTAGE, DONE;
reg [9:0] tmp;

  always @(posedge C) begin
    if (CLR) begin
      tmp = 10'd0;
    end else if (ENABLE) begin
		  tmp = tmp + 10'd1;
    end
	  if (tmp <= 10'd64) begin
			STAGEONE <= 1;
			STAGETWO <= 0;
			STAGETHREE <= 0;
      OUTPUTSTAGE <= 0;
      DONE <= 0;
		end else if (tmp <= 10'd86 && tmp>10'd64) begin
			STAGEONE <= 0;
			STAGETWO <= 1;
			STAGETHREE <= 0;
      OUTPUTSTAGE <= 0;
      DONE <= 0;
		end else if (tmp > 10'd86 && tmp<=10'd186) begin
			STAGEONE <= 0;
			STAGETWO <= 0;
			STAGETHREE <= 1;
      OUTPUTSTAGE <= 0;
      DONE <= 0;
    end else if (tmp > 10'd186 && tmp<=10'd410) begin
			STAGEONE <= 0;
			STAGETWO <= 0;
			STAGETHREE <= 0;
      OUTPUTSTAGE <= 1;
      DONE <= 0;
	  end else begin
			STAGEONE <= 0;
			STAGETWO <= 0;
			STAGETHREE <= 0;
      OUTPUTSTAGE <= 0;
      DONE <= 1;
	  end
  end
  assign Q = tmp;
endmodule
