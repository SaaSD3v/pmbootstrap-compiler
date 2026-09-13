# postmarketOS Device Builder

Generic postmarketOS builder core with one branch per device.

## Branching rule

- `main`: generic infrastructure only. No device-specific configuration.
- `device/<codename>`: one branch per device, containing `config/device.env`.

The first device branch is `device/samsung-a21s`.

## Current repository state

The reusable build core is present in `main`, including:

- `scripts/build-pmos.sh`
- `config/device.env.example`
- `docs/DESIGN.md`

The A21s branch contains its own `config/device.env` and uses:

- `device-samsung-a21s`
- `firmware-samsung-a21s`
- `linux-postmarketos-exynos850`
- `edge`
- Odin export enabled

The build script supports Console and Phosh and records the resolved pmaports and pmbootstrap SHAs in `BUILD-INFO.txt`.

## Intended Actions layout

The complete project design uses two independent workflows:

- `.github/workflows/console.yml`
- `.github/workflows/phosh.yml`

Each workflow targets only `device/*` branches and produces GitHub artifacts. The full prepared project, including the workflow definitions and GoFile helper, is available in the delivery bundle generated alongside this repository setup.

## Reproducibility

Device branches may track `pmaports/main`; manual builds can override pmaports and pmbootstrap refs. For Samsung Galaxy A21s regression testing, a useful historical pmaports baseline is:

`3ef06e837fa6ead3ea9c5b24a50350bcc5873eba`

## Add another device

Create a branch from `main` named `device/<codename>`, copy `config/device.env.example` to `config/device.env`, and fill in that device's package names and kernel selector. Keep device-specific data out of `main`.
