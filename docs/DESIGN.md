# Design decisions

## Default branch and device branches

`main` is intentionally device-neutral. It contains reusable workflows, scripts,
documentation, and a configuration template only. Device-specific values live in
`device/<codename>` branches as `config/device.env`.

The two workflow YAML files remain on `main` because GitHub requires a workflow
using `workflow_dispatch` to exist on the default branch before it can be run
manually. The workflow job itself is guarded so it only runs on a `device/*` ref.
This preserves a clean default branch while retaining GitHub's branch selector in
the **Run workflow** UI.

GitHub reference:
https://docs.github.com/actions/how-tos/manage-workflow-runs/manually-run-a-workflow

## pmaports and pmbootstrap

The builder checks out pmaports separately and passes that exact path to
pmbootstrap with `-p/--aports`. This is the supported pmbootstrap interface for
selecting a pmaports checkout. The resolved pmaports and pmbootstrap SHAs are
stored in every build's `BUILD-INFO.txt`.

A device branch may track `pmaports/main`, while a manual build can override the
ref with a branch, tag, or commit for regression testing and reproducibility.

postmarketOS references:
- https://docs.postmarketos.org/pmbootstrap/main/usage.html
- https://docs.postmarketos.org/pmbootstrap/main/installation.html

## Kernel validation

Before compiling, the device profile may enable `pmbootstrap kconfig check`.
This uses the device architecture explicitly. Kernel, firmware, and device
packages are then built before `pmbootstrap install` creates the image.

postmarketOS reference:
https://docs.postmarketos.org/pmbootstrap/main/usage.html

## Console and Phosh

Console and Phosh are separate GitHub Actions workflows by design. They share
only the generic shell implementation, which avoids configuration drift without
combining the two user-visible build jobs.

## Exports

Every build performs a normal `pmbootstrap export`. Device profiles may also
set `EXPORT_ODIN=true`; in that case a separate `pmbootstrap export --odin` is
produced. Checksums and build metadata are added after export.

postmarketOS reference:
https://docs.postmarketos.org/pmbootstrap/main/usage.html#pmbootstrap-export

## Gofile

The distribution directory is packed as a `.tar.zst` archive to avoid uploading
large sparse/raw filesystem images individually. The upload step:

1. resolves the account and root folder from the API token;
2. creates a dedicated public folder for that workflow run;
3. uploads the archive and its SHA-256 file through the global upload endpoint;
4. validates every JSON response has `status = ok`;
5. publishes the resulting public Gofile link in the GitHub Job Summary.

The API token is only read from the `GOFILE_API_KEY` Actions secret.

Gofile reference:
https://gofile.io/api

## Image password

The generated image password is read from the `PMOS_PASSWORD` Actions secret.
The workflows intentionally have no default password and fail if the secret is
missing, so downloadable builds do not silently ship with a public hard-coded
credential.
