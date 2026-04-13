module neuron (
    input  wire        CLK,
    input  wire        RST,          // active-low
    input  wire [7:0]  R_IN, G_IN, B_IN,
    input  wire signed [31:0] w1, w2, w3,
    input  wire signed [31:0] BIAS,
    output wire [7:0]  out
);
 
    // ----------------------------------------------------------
    // Stage 1 - register → multiplier → register
    //   r_multiplier_r internally: IN1 registered on cycle 1,
    //   OUT (= RIN * IN2) registered on cycle 2.
    //   WOUT holds 32 meaningful bits;
    // ----------------------------------------------------------
    wire signed [31:0] mul1_out, mul2_out, mul3_out;
 
    r_multiplier_r #(.WIN1(8), .WIN2(32), .WOUT(32)) MUL1 (
        .CLK(CLK), .RST(RST),
        .IN1(R_IN), .IN2(w1),
        .OUT(mul1_out)
    );
 
    r_multiplier_r #(.WIN1(8), .WIN2(32), .WOUT(32)) MUL2 (
        .CLK(CLK), .RST(RST),
        .IN1(G_IN), .IN2(w2),
        .OUT(mul2_out)
    );
 
    r_multiplier_r #(.WIN1(8), .WIN2(32), .WOUT(32)) MUL3 (
        .CLK(CLK), .RST(RST),
        .IN1(B_IN), .IN2(w3),
        .OUT(mul3_out)
    );
 
    // ----------------------------------------------------------
    // Stage 2 - adder → register  (instantiated 3 times)
    //   ADD1: mul1 + mul2        → 32-bit registered sum1
    //   ADD2: mul3 + BIAS        → 32-bit registered sum2
    //   ADD3: sum1 + sum2        → 32-bit registered sum3
    // ----------------------------------------------------------
 
    wire signed [31:0] sum1_out, sum2_out, sum3_out;
 
    adder_r #(.WIN1(32), .WIN2(32), .WOUT(32)) ADD1 (
        .CLK(CLK), .RST(RST),
        .IN1(mul1_out),
        .IN2(mul2_out),
        .OUT(sum1_out)
    );
 
    adder_r #(.WIN1(32), .WIN2(32), .WOUT(32)) ADD2 (
        .CLK(CLK), .RST(RST),
        .IN1(mul3_out),
        .IN2(BIAS),
        .OUT(sum2_out)
    );
 
    adder_r #(.WIN1(32), .WIN2(32), .WOUT(32)) ADD3 (
        .CLK(CLK), .RST(RST),
        .IN1(sum1_out),
        .IN2(sum2_out),
        .OUT(sum3_out)
    );

     // ----------------------------------------------------------
    // Stage 3 - clamp_shift_r (clamp + 2-bit shift + register)
    //   Clamps sum3 to [0, 32767] (16-bit ceiling),
    //   right-shifts 2 bits → registered 14-bit ROM address.
    // ----------------------------------------------------------
    wire [13:0] clamp_r;
 
    clamp_shift_r CL (
        .CLK(CLK), .RST(RST),
        .in (sum3_out),
        .out(clamp_r)
    );
 
    // ----------------------------------------------------------
    // Stage 4 - ROM_r (lookup + registered output)
    // ----------------------------------------------------------
    ROM_r ROM_inst (
        .CLK (CLK), .RST(RST),
        .address(clamp_r),
        .q(out)
    );
 
endmodule