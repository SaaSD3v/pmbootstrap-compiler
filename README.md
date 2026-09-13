# postmarketOS Device Builder — Motorola Moto G7 Power

This branch is the device-specific profile for `motorola-ocean`.

## Device profile

- Model: Motorola Moto G7 Power
- Codename: `ocean`
- SoC: Qualcomm Snapdragon 632 (SDM632 / MSM8953 family)
- Architecture: `aarch64`
- Device package: `device-motorola-ocean`
- Firmware package: `firmware-motorola-ocean`
- Kernel package: `linux-postmarketos-qcom-msm8953`
- Kernel line: postmarketOS generic MSM8953 mainline/close-to-mainline kernel
- DTB: `qcom/sdm632-motorola-ocean`
- Boot stack: `lk2nd-msm8953` as required by the official device package
- Channel: `edge`
- Odin export: disabled

This branch intentionally does not patch or replace the Ocean port. It builds the existing postmarketOS `motorola-ocean` device package and the official generic MSM8953 kernel as provided by pmaports.

Shared build logic is inherited from `main`; device-specific values stay in `config/device.env` on this branch.

## Build outputs

The shared Console and Phosh workflows build the selected UI, export the standard pmbootstrap images, publish a GitHub Actions artifact, and upload only the generated build outputs to GoFile.

`BUILD-INFO.txt` remains in the GitHub artifact and records the exact resolved pmaports and pmbootstrap commits used for each run.
