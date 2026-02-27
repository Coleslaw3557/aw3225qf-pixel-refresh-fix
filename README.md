# AW3225QF Pixel Refresh Loop Fix

## Problem

Firmware **M2B107** and **M2B109** for the Alienware AW3225QF can cause an infinite pixel refresh loop. The monitor displays "the refresh process did not finish," the OSD is inaccessible, and no video signal passes through. This is a known, widespread issue confirmed across Dell support forums.

## Requirements

- Mac with Apple Silicon (M1/M2/M3/M4) connected via USB-C or DisplayPort/Thunderbolt
- Apple Command Line Tools (`xcode-select --install`)
- Make sure the USB-C/DisplayPort cable is plugged in before starting

## Step 1: Compile the DDC tool

Save `ddc_write.m` (included in this repo), then:

```bash
clang -o ddc_write ddc_write.m -framework IOKit -framework CoreGraphics -framework Foundation
```

## Step 2: Start the reset loop

Run this **before** powering the monitor. It will continuously send factory reset commands until you stop it:

```bash
while true; do ./ddc_write 0x04 1 && ./ddc_write 0x05 1 && ./ddc_write 0x06 1 && ./ddc_write 0x08 1 && ./ddc_write 0xE0 1 && ./ddc_write 0x04 1 && ./ddc_write 0x0C 1; sleep 0.5; done
```

## Step 3: Get the monitor into a briefly-connected state

With the loop running:

1. Unplug the monitor's power cable.
2. Hold down the monitor's physical button.
3. While holding the button, plug the power cable back in.
4. The monitor should briefly display a signal — the loop will catch it and send the reset commands during that window.

## Step 4: Wait

Let the monitor sit. Do not unplug it, do not press any buttons. The `0x0C` command saves the reset state to NVRAM. Give it a few minutes to stabilize, then `Ctrl+C` the loop.

## Step 5: Verify

Power cycle the monitor by unplugging power, waiting 10 seconds, and plugging back in (no button hold). It should boot normally.

**Avoid using the monitor's power button** — it may retrigger the pixel refresh cycle until Dell releases a firmware patch.

## VCP codes sent

| Code | Function |
|------|----------|
| 0x04 | Restore Factory Defaults |
| 0x05 | Restore Factory Luminance/Contrast |
| 0x06 | Restore Factory Geometry |
| 0x08 | Restore Factory Color Defaults |
| 0xE0 | Restore Manufacturer Specific Defaults |
| 0x0C | Save Current Settings to NVRAM |

## Notes

- The `ddc_write` tool uses `IOAVServiceWriteI2C`, the same Apple Silicon DDC/CI API used by m1ddc and BetterDisplay. It does not require sudo.
- This may not work over the built-in HDMI port on M1 or entry-level M2 Macs. USB-C/DisplayPort/Thunderbolt only.
- Standard DDC reset commands sent while the refresh loop is active get ACK'd on I2C but are ignored by the monitor. The button-hold power trick creates a brief window where commands are actually processed.
- Without `0x0C` (Save Current Settings), the reset does not persist — power cycling reverts the monitor back into the refresh loop. The save command is critical.
- After recovery, avoid firmware M2B107/M2B109 or check Dell support for a patched version before updating again.
