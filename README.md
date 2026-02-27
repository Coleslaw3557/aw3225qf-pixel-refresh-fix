# AW3225QF Pixel Refresh Loop Fix

## Problem

Firmware **M2B107** and **M2B109** for the Alienware AW3225QF can cause an infinite pixel refresh loop. The monitor displays "the refresh process did not finish," the OSD is inaccessible, and no video signal passes through. This is a known, widespread issue confirmed across Dell support forums.

## Requirements

- Mac with Apple Silicon (M1/M2/M3/M4) connected via USB-C or DisplayPort
- Apple Command Line Tools (`xcode-select --install`)

## Step 1: Compile the DDC tool

Save `ddc_write.m` (included in this repo), then:

```bash
clang -o ddc_write ddc_write.m -framework IOKit -framework CoreGraphics -framework Foundation
```

## Step 2: Get the monitor into a briefly-connected state

1. Unplug the monitor's power cable.
2. Hold down the monitor's physical button.
3. While holding the button, plug the power cable back in.
4. The monitor should briefly display a signal for a few seconds.

## Step 3: Send factory reset commands

The moment the display appears, run:

```bash
./ddc_write 0x04 1 && ./ddc_write 0x05 1 && ./ddc_write 0x06 1 && ./ddc_write 0x08 1 && ./ddc_write 0xE0 1 && ./ddc_write 0x04 1
```

**Unplug the power cable immediately after the command completes. You must unplug the monitor before the screen goes black!**

## Step 4: Verify

Plug the monitor back in normally. It should boot without entering the pixel refresh loop.

## VCP codes sent

| Code | Function |
|------|----------|
| 0x04 | Restore Factory Defaults |
| 0x05 | Restore Factory Luminance/Contrast |
| 0x06 | Restore Factory Geometry |
| 0x08 | Restore Factory Color Defaults |
| 0xE0 | Restore Manufacturer Specific Defaults |

## Notes

- The `ddc_write` tool uses `IOAVServiceWriteI2C`, the same Apple Silicon DDC/CI API used by m1ddc and BetterDisplay. It does not require sudo.
- This may not work over the built-in HDMI port on M1 or entry-level M2 Macs. USB-C/DisplayPort/Tbolt.
- Make sure the usb cable is plugged in.
- Standard DDC reset commands alone (without the button-hold power cycle trick) do not work — the monitor ACKs the I2C writes but ignores them while the refresh loop is active.
