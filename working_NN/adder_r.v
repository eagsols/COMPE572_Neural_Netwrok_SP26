module adder_r #(parameter    WIN1 = 32,
                            WIN2 = 32,
                            WOUT = 32
                        
)(
    input signed [WIN1-1:0] IN1,
    input signed [WIN2-1:0] IN2,
    input CLK, RST,
    output reg signed [WOUT-1:0] OUT
);
    always @(posedge CLK or negedge RST) begin
        if(!RST) begin
            OUT <= 0;
        end
        else begin
            OUT <= IN1 + IN2;
        end   
    end    
endmodule