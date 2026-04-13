module clamp_shift_r (
    input  wire        CLK,
    input  wire        RST,        // active-low reset
    input  wire signed [31:0] in,
    output reg [13:0] out
);
    always @(posedge CLK or negedge RST) begin
        if (!RST)
            out <= 14'd0;
        else if (in < -32768)
            out <= 14'd0;
        else if (in > 32767)
            out <= 14'd16383;
        else
            out <= (in + 32768) >> 2;
    end
endmodule