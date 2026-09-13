# postmarketOS Device Builder — Samsung Galaxy A21s

This branch is the device-specific profile for `samsung-a21s`.

## Device profile

- Model: Samsung Galaxy A21s (SM-A217F)
- SoC: Exynos 850
- Architecture: `aarch64`
- Device package: `device-samsung-a21s`
- Firmware package: `firmware-samsung-a21s`
- Kernel package: `linux-postmarketos-exynos850`
- Channel: `edge`
- Odin export: enabled

Shared build logic is inherited from `main`; device-specific values stay in `config/device.env` on this branch.

## Reproducibility

Normal builds can track `pmaports/main`. For regression testing against the historical A21s introduction baseline, use:

`3ef06e837fa6ead3ea9c5b24a50350bcc5873eba`

The build core records the resolved pmaports and pmbootstrap SHAs in `BUILD-INFO.txt`.

## Intended workflows

The project design uses two separate GitHub Actions workflows, one for Console and one for Phosh. The complete prepared project files, including those workflow YAMLs and the GoFile helper, are included in the delivery bundle prepared for this repository.
