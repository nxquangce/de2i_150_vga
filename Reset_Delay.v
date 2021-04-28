module Reset_Delay(iCLK,oRESET,iRST_n);
input       iCLK;
input       iRST_n;
output reg  oRESET;
reg	[19:0]  Cont;

always@(posedge iCLK)
begin
    if(Cont!=20'hFFFFF)
    begin
        Cont	<=	Cont+1;
        oRESET	<=	1'b0;
    end
    else
    oRESET	<=	iRST_n;
end

endmodule