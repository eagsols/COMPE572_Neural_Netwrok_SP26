// =============================================================================
// tb_nn_top.v
// Testbench for nn_top.v
//
// Reads stimulus.hex - one pixel per line, format RRGGBB (hex, no prefix).
// Drives R_IN, G_IN, B_IN every clock cycle after reset.
// Captures R_OUT, G_OUT, B_OUT when VALID_OUT is high.
// Dumps results to output.hex (same RRGGBB format).
//
// Usage (Icarus Verilog example):
//   iverilog -o sim tb_nn_top.v nn_top.v neuron.v r_multiplier_r.v \
//            adder_r.v clamp_shift.v ROM.v color_mapper.v
//   vvp sim
// =============================================================================

`timescale 1ns/1ps

module tb_nn_top;

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    reg CLK, RST;

    localparam CLK_PERIOD = 5; // 5 ns → 200 MHz

    initial CLK = 0;
    always #(CLK_PERIOD/2) CLK = ~CLK;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg  [7:0] R_IN, G_IN, B_IN;
    reg        VALID_IN;

    wire [7:0] R_OUT, G_OUT, B_OUT;
    wire       VALID_OUT;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    nn_top DUT (
        .CLK      (CLK),
        .RST      (RST),
        .R_IN     (R_IN),
        .G_IN     (G_IN),
        .B_IN     (B_IN),
        .VALID_IN (VALID_IN),
        .R_OUT    (R_OUT),
        .G_OUT    (G_OUT),
        .B_OUT    (B_OUT),
        .VALID_OUT(VALID_OUT)
    );

    // -------------------------------------------------------------------------
    // Stimulus memory  (4096 pixels max, each stored as 24-bit R,G,B packed)
    // -------------------------------------------------------------------------
    reg [23:0] stim_mem [0:262143];
    integer    num_pixels;
    integer    pix_idx;      // index into stim_mem for driving
    integer    out_count;    // number of output pixels captured

    integer    out_file;     // file handle for output.hex

    // -------------------------------------------------------------------------
    // Load stimulus file
    // -------------------------------------------------------------------------
    initial begin
        $readmemh("stimulus.hex", stim_mem);
        // Count how many lines were actually loaded
        // (readmemh fills from 0; we loaded at most 4096)
        num_pixels = 262144;
        $display("[TB] Loaded %0d pixels from stimulus.hex", num_pixels);
    end

    // -------------------------------------------------------------------------
    // Open output file
    // -------------------------------------------------------------------------
    initial begin
        out_file = $fopen("output.hex", "w");
        if (out_file == 0) begin
            $display("[TB] ERROR: cannot open output.hex for writing");
            $finish;
        end
    end

    // -------------------------------------------------------------------------
    // Reset sequence
    // -------------------------------------------------------------------------
    initial begin
        RST      = 0;          // assert reset (active-low)
        R_IN     = 8'h00;
        G_IN     = 8'h00;
        B_IN     = 8'h00;
        VALID_IN = 1'b0;
        pix_idx  = 0;
        out_count = 0;

        repeat(4) @(posedge CLK);  // hold reset for 4 cycles
        @(negedge CLK);
        RST = 1;               // release reset
        $display("[TB] Reset released at time %0t", $time);
    end

    // -------------------------------------------------------------------------
    // Drive input pixels
    // Each pixel is presented for exactly 1 clock cycle.
    // After all pixels sent, we keep driving zeros for LATENCY extra cycles
    // so the last pixel can flush through the pipeline.
    // -------------------------------------------------------------------------
    localparam LATENCY = 15;

    integer flush_count;

    initial begin
        // Wait for reset release
        wait (RST == 1);
        @(posedge CLK); #1;   // small offset so we write just after posedge

        // ---- Drive real pixels ----
        for (pix_idx = 0; pix_idx < num_pixels; pix_idx = pix_idx + 1) begin
            R_IN     = stim_mem[pix_idx][23:16];
            G_IN     = stim_mem[pix_idx][15: 8];
            B_IN     = stim_mem[pix_idx][ 7: 0];
            VALID_IN = 1'b1;
            @(posedge CLK); #1;
        end

        // ---- Flush cycles (pipeline drain) ----
        VALID_IN = 1'b0;
        R_IN = 8'h00; G_IN = 8'h00; B_IN = 8'h00;
        repeat(LATENCY + 2) @(posedge CLK);

        // Close file and finish
        $fclose(out_file);
        $display("[TB] Done. %0d output pixels written to output.hex", out_count);
        $finish;
    end

    // -------------------------------------------------------------------------
    // Capture output pixels whenever VALID_OUT is high
    // -------------------------------------------------------------------------
    always @(posedge CLK) begin
        if (VALID_OUT) begin
            // Write RRGGBB line to output.hex
            $fdisplay(out_file, "%02X%02X%02X", R_OUT, G_OUT, B_OUT);

            // Also print first 10 and last 10 to console for quick check
            if (out_count < 10 || out_count >= num_pixels - 10)
                $display("[TB] pixel[%0d] R=%02X G=%02X B=%02X  (%s)",
                         out_count, R_OUT, G_OUT, B_OUT,
                         (R_OUT == 8'hFF) ? "WHITE" : "black");

            out_count = out_count + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Safety timeout  (avoid infinite simulation)
    // -------------------------------------------------------------------------
    initial begin
        #((num_pixels + LATENCY + 20) * CLK_PERIOD * 10);
        $display("[TB] TIMEOUT");
        $fclose(out_file);
        $finish;
    end

    // -------------------------------------------------------------------------
    // Optional waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("nn_top.vcd");
        $dumpvars(0, tb_nn_top);
    end

endmodule