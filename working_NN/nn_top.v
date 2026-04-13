// =============================================================================
// nn_top.v
// Top-level Neural Network for Color Detection
//
// Architecture  :  [3 inputs] -> [3 hidden neurons] -> [1 output neuron]
//                                                    -> [color mapper]
//
// Network weights: from FPGA_plain/nn_rgb.vhd (fixed-point, factor=32,
//                  bias extra factor=256)
//
//   Hidden layer weights (R, G, B, BIAS):
//     hidden0 :  w1= 29,  w2=-45,  w3=-87,  bias=-18227
//     hidden1 :  w1=-361, w2=126,  w3=371,  bias=  2845
//     hidden2 :  w1=-313, w2= 96,  w3=337,  bias=  4513
//
//   Output layer weights (h0, h1, h2, BIAS):
//     output0 :  w1= 51,  w2=-158, w3=-129, bias= 41760
//
// Pipeline latency (all stages registered):
//   neuron  = 5 cycles  (mul:2 + add:3 + clamp:1 + ROM:1 = 7... see note)
//   NOTE: neuron internal latency:
//     r_multiplier_r  : 2 cycles (input reg + multiply reg)
//     adder_r x3      : 3 cycles (ADD1, ADD2, ADD3 in sequence)
//                       ADD1 and ADD2 share the same input cycle, ADD3 takes +1
//     clamp_shift_r   : 1 cycle
//     ROM_r           : 1 cycle
//     Total per neuron: 2 + 2 + 1 + 1 + 1 = 7 cycles
//
//   hidden layer and output layer are the SAME module so:
//     Total pipeline = 7 (hidden) + 7 (output) + 1 (mapper) = 15 cycles
//
// Ports:
//   CLK            - pixel clock
//   RST            - active-low asynchronous reset (matches sub-modules)
//   R_IN, G_IN, B_IN  - 8-bit unsigned input pixel
//   R_OUT, G_OUT, B_OUT - 8-bit output pixel (white=detected, black=not)
//   VALID_IN       - pulse high for 1 cycle when R/G/B input is valid
//   VALID_OUT      - pulses high 15 cycles after VALID_IN
// =============================================================================

module nn_top (
    input  wire        CLK,
    input  wire        RST,          // active-low, async

    // Input pixel
    input  wire [7:0]  R_IN,
    input  wire [7:0]  G_IN,
    input  wire [7:0]  B_IN,
    input  wire        VALID_IN,     // 1-cycle strobe: input pixel is valid

    // Output pixel
    output wire [7:0]  R_OUT,
    output wire [7:0]  G_OUT,
    output wire [7:0]  B_OUT,
    output wire        VALID_OUT     // 1-cycle strobe: output pixel is valid
);

    // =========================================================================
    // 1.  WEIGHTS AND BIASES  (from FPGA_plain/nn_rgb.vhd)
    // =========================================================================

    // --- Hidden neuron 0 ---
    localparam signed [31:0] H0_W1   =  32'sd29;
    localparam signed [31:0] H0_W2   = -32'sd45;
    localparam signed [31:0] H0_W3   = -32'sd87;
    localparam signed [31:0] H0_BIAS = -32'sd18227;

    // --- Hidden neuron 1 ---
    localparam signed [31:0] H1_W1   = -32'sd361;
    localparam signed [31:0] H1_W2   =  32'sd126;
    localparam signed [31:0] H1_W3   =  32'sd371;
    localparam signed [31:0] H1_BIAS =  32'sd2845;

    // --- Hidden neuron 2 ---
    localparam signed [31:0] H2_W1   = -32'sd313;
    localparam signed [31:0] H2_W2   =  32'sd96;
    localparam signed [31:0] H2_W3   =  32'sd337;
    localparam signed [31:0] H2_BIAS =  32'sd4513;

    // --- Output neuron 0 ---
    localparam signed [31:0] O0_W1   =  32'sd51;
    localparam signed [31:0] O0_W2   = -32'sd158;
    localparam signed [31:0] O0_W3   = -32'sd129;
    localparam signed [31:0] O0_BIAS =  32'sd41760;

    // =========================================================================
    // 2.  HIDDEN LAYER  (3 neurons, all see R_IN, G_IN, B_IN)
    // =========================================================================

    wire [7:0] h0_out, h1_out, h2_out;

    neuron HIDDEN0 (
        .CLK  (CLK),   .RST  (RST),
        .R_IN (R_IN),  .G_IN (G_IN),  .B_IN (B_IN),
        .w1   (H0_W1), .w2   (H0_W2), .w3   (H0_W3),
        .BIAS (H0_BIAS),
        .out  (h0_out)
    );

    neuron HIDDEN1 (
        .CLK  (CLK),   .RST  (RST),
        .R_IN (R_IN),  .G_IN (G_IN),  .B_IN (B_IN),
        .w1   (H1_W1), .w2   (H1_W2), .w3   (H1_W3),
        .BIAS (H1_BIAS),
        .out  (h1_out)
    );

    neuron HIDDEN2 (
        .CLK  (CLK),   .RST  (RST),
        .R_IN (R_IN),  .G_IN (G_IN),  .B_IN (B_IN),
        .w1   (H2_W1), .w2   (H2_W2), .w3   (H2_W3),
        .BIAS (H2_BIAS),
        .out  (h2_out)
    );

    // =========================================================================
    // 3.  OUTPUT LAYER  (1 neuron, inputs are h0/h1/h2 from hidden layer)
    //
    //     The output neuron reuses the same neuron module.
    //     Its "R_IN/G_IN/B_IN" ports carry h0/h1/h2 instead of raw RGB.
    // =========================================================================

    wire [7:0] nn_out;

    neuron OUTPUT0 (
        .CLK  (CLK),    .RST  (RST),
        .R_IN (h0_out), .G_IN (h1_out), .B_IN (h2_out),
        .w1   (O0_W1),  .w2   (O0_W2),  .w3   (O0_W3),
        .BIAS (O0_BIAS),
        .out  (nn_out)
    );

    // =========================================================================
    // 4.  COLOR MAPPER
    // =========================================================================

    color_mapper MAPPER (
        .CLK   (CLK),
        .RST   (RST),
        .nn_out(nn_out),
        .r_out (R_OUT),
        .g_out (G_OUT),
        .b_out (B_OUT)
    );

    // =========================================================================
    // 5.  VALID PIPELINE  (15-cycle delay shift register)
    //
    //     Neuron latency  = 7 cycles  (see header)
    //     Hidden layer    = 7 cycles
    //     Output layer    = 7 cycles  (runs in parallel on hidden outputs)
    //     Color mapper    = 1 cycle
    //     Total           = 7 + 7 + 1 = 15 cycles
    // =========================================================================

    localparam LATENCY = 15;

    reg [LATENCY-1:0] valid_pipe;

    always @(posedge CLK or negedge RST) begin
        if (!RST)
            valid_pipe <= {LATENCY{1'b0}};
        else
            valid_pipe <= {valid_pipe[LATENCY-2:0], VALID_IN};
    end

    assign VALID_OUT = valid_pipe[LATENCY-1];

endmodule