#!/usr/bin/env python3
# =============================================================================
# img_to_hex.py
# Converts a traffic sign image into a .hex stimulus file for Xcelium simulation
#
# Output format (one pixel per line):
#   RRGGBB    e.g. FF0000 = pure red pixel
#
# Usage:
#   python3 img_to_hex.py --input traffic_sign.jpg --output stimulus.hex
#   python3 img_to_hex.py --input traffic_sign.jpg --output stimulus.hex --width 64 --height 64
#
# The script also writes a metadata file (stimulus_info.txt) containing
# the image dimensions so the testbench knows how many pixels to simulate.
# =============================================================================

import argparse
from PIL import Image

def image_to_hex(input_path, output_path, width=64, height=64):

    # -------------------------------------------------------------------------
    # Load and resize image
    # Resize to a fixed resolution to keep simulation time manageable.
    # 64x64 = 4096 pixels — a good balance for simulation speed vs detail.
    # Use a larger size (128x128) if you need more detail.
    # -------------------------------------------------------------------------
    img = Image.open(input_path)
    img = img.convert("RGB")              # ensure RGB, strip alpha if present
    img = img.resize((width, height), Image.LANCZOS)

    pixels = list(img.getdata())          # list of (R, G, B) tuples
    total_pixels = len(pixels)

    print(f"  Image loaded : {input_path}")
    print(f"  Resized to   : {width} x {height} = {total_pixels} pixels")

    # -------------------------------------------------------------------------
    # Write hex stimulus file
    # Format: one pixel per line as RRGGBB (6 hex digits)
    # The testbench reads this with $readmemh()
    # -------------------------------------------------------------------------
    with open(output_path, "w") as f:
        for r, g, b in pixels:
            f.write(f"{r:02X}{g:02X}{b:02X}\n")

    print(f"  Hex file     : {output_path}  ({total_pixels} lines)")

    # -------------------------------------------------------------------------
    # Write metadata file so the testbench knows image dimensions
    # -------------------------------------------------------------------------
    info_path = output_path.replace(".hex", "_info.txt")
    with open(info_path, "w") as f:
        f.write(f"width={width}\n")
        f.write(f"height={height}\n")
        f.write(f"total_pixels={total_pixels}\n")
        f.write(f"source={input_path}\n")

    print(f"  Info file    : {info_path}")
    print(f"  Done.")

    return width, height, total_pixels

# =============================================================================
# Main
# =============================================================================
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert image to hex stimulus file for Xcelium simulation")
    parser.add_argument("--input",  required=True,  help="Input image file (jpg, png, bmp)")
    parser.add_argument("--output", required=True,  help="Output hex file (e.g. stimulus.hex)")
    parser.add_argument("--width",  type=int, default=64, help="Resize width  (default: 64)")
    parser.add_argument("--height", type=int, default=64, help="Resize height (default: 64)")
    args = parser.parse_args()

    image_to_hex(args.input, args.output, args.width, args.height)