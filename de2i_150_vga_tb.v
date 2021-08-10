module de2i_150_vga_tb;

reg [17:0] SW;
reg  [3:0] KEY;
reg        CLK;

de2i_150_vga dut(
    .CLOCK_50       (CLK),
    .SW             (SW),
    .KEY            (KEY),
    .VGA_B          (),
    .VGA_BLANK_N    (),
    .VGA_CLK        (),
    .VGA_G          (),
    .VGA_HS         (),
    .VGA_R          (),
    .VGA_SYNC_N     (),
    .VGA_VS         ()	
);

initial begin
    CLK <= 0;

    forever begin
        #5 CLK <= ~CLK;
    end
end

initial begin
    SW <= 0;
    KEY <= 1;

    #20
    SW[1] <= 1;
    KEY[0] <= 0;

    #20
    SW <= 0;
    KEY <= 1;
end

endmodule