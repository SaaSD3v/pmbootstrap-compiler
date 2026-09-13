# postmarketOS Device Builder — Motorola Moto G7 Play

This branch is the device-specific profile for `motorola-channel`.

## Device profile

- Model: Motorola Moto G7 Play / Moto G7 Optimo
- Codename: `channel`
- SoC: Qualcomm Snapdragon 632 (SDM632)
- Architecture: `aarch64`
- Device package: `device-motorola-channel`
- Firmware package: `firmware-motorola-channel`
- Kernel package: `linux-motorola-channel`
- Kernel line: downstream Linux 4.9.206
- Channel: `edge`
- Flash method from the port: `fastboot`
- Odin export: disabled

This branch intentionally does not patch, replace, or mainline the device kernel. It builds the existing postmarketOS `motorola-channel` port as provided by pmaports.

Shared build logic is inherited from `main`; device-specific values stay in `config/device.env` on this branch.

## Build outputs

The shared Console and Phosh workflows build the selected UI, export the standard pmbootstrap images, publish a GitHub Actions artifact, and upload the staged build files to GoFile.

`BUILD-INFO.txt` records the exact resolved pmaports and pmbootstrap commits used for each run.
