# postmarketOS Device Builder

GitHub Actions builder for postmarketOS device branches.

## Branching rule

- `main`: generic build infrastructure only. No device-specific configuration.
- `device/<codename>`: one branch per device, containing `config/device.env`.
- Two independent workflows are kept on every branch:
  - `.github/workflows/console.yml`
  - `.github/workflows/phosh.yml`

The workflow files also stay on `main` because GitHub requires a `workflow_dispatch`
workflow to exist on the default branch before the **Run workflow** button can be used.
The jobs themselves only run when the selected ref is `device/*`.

## Required secrets

Create these repository Actions secrets:

- `GOFILE_API_KEY`: Gofile API token.
- `PMOS_PASSWORD`: password embedded in the generated postmarketOS image.

Do not hard-code either value in the repository.

## How to build

Open **Actions**, select **postmarketOS Console** or **postmarketOS Phosh**,
click **Run workflow**, and select the desired `device/<codename>` branch.

A push to a `device/*` branch also starts its Console and Phosh workflows.
Documentation-only changes (`README.md` and `DEVICE.md`) do not trigger builds.

## Reproducibility

Each build records the exact pmaports and pmbootstrap Git SHAs in
`BUILD-INFO.txt`. The manual workflow also accepts optional `pmaports_ref` and
`pmbootstrap_ref` overrides so an old build can be reproduced from a commit,
tag, or branch.

By default, device branches can track `pmaports/main`; the exact SHA actually
used is always recorded in the output.

## Output

Each successful build produces:

- a GitHub Actions artifact containing the exported postmarketOS files;
- `BUILD-INFO.txt` and `SHA256SUMS`;
- an optional Odin export when enabled by the device config;
- a compressed `.tar.zst` package for distribution;
- a `.sha256` checksum for that package;
- a Gofile public folder link in the GitHub Actions Job Summary.

## Add another device

Create a branch from `main` named `device/<codename>`, copy
`config/device.env.example` to `config/device.env`, and fill in the package
names and kernel selector for that device. Keep device-specific data out of
`main`.
