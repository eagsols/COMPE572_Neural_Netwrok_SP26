module r_multiplier_r #(parameter   WIN1 = 8,
                                    WIN2 = 32,
                                    WOUT = 32)
(
    input CLK, RST,
    input [WIN1-1:0] IN1,
    input signed [WIN2-1:0] IN2,
    output reg signed [WOUT-1:0] OUT
);
    wire signed [8:0] IN1_signed = {1'b0, IN1};
    reg signed [8:0] RIN;


    always @(posedge CLK or negedge RST)
        if(!RST) begin
            RIN <= 0;
            OUT <= 0;
        end
        else begin
            RIN <= IN1_signed;
            OUT <= RIN * IN2;
        end   
endmodule
