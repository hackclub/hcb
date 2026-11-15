# libheif backport for Ubuntu 24.04 LTS (Noble)

This directory builds HCB's libheif 1.23.4 packages for Ubuntu 24.04 LTS
(Noble) from the upstream 1.23.4 source and Debian's 1.23.3 packaging. The
input checksums are pinned in `build-noble.sh`.

Noble satisfies every Debian build dependency except `libkvazaar-dev`.
`noble.patch` therefore disables only the optional kvazaar HEIC encoder and
sets the package version to `1.23.4-1hcb1~ubuntu24.04.1`.

Ubuntu's official package search returns
[no `libkvazaar-dev` result for Noble](https://packages.ubuntu.com/search?keywords=libkvazaar-dev&searchon=names&suite=noble&section=all).
The broader [`kvazaar` package listing](https://packages.ubuntu.com/kvazaar)
shows `libkvazaar-dev` only in later Ubuntu releases.

The host needs Bash, curl, `sha256sum`, `realpath`, Docker, outbound internet
access, and several gigabytes of free disk space. The output is amd64, matching
HCB's servers. An amd64 host runs it natively; an ARM host needs Docker
configured to emulate `linux/amd64`.

Run the build with:

```sh
scripts/libheif/build-noble.sh /path/to/output
```

Docker's normal network is used by default. In an environment whose Docker
daemon has no bridge network, set `LIBHEIF_DOCKER_NETWORK=host`.

The build defaults to two parallel compiler jobs to limit peak memory use,
especially when building amd64 packages under emulation. A larger native build
host can override this with `LIBHEIF_BUILD_JOBS`, for example:

```sh
LIBHEIF_BUILD_JOBS=4 scripts/libheif/build-noble.sh /path/to/output
```

The script builds in `ubuntu:24.04`, runs the upstream test suite as part of
`dpkg-buildpackage`, and writes source artifacts, binary packages, build
metadata, and `SHA256SUMS` to the output directory. It does not publish or
install anything.

## GitHub Actions build

The repository includes a **Build libheif packages for Ubuntu 24.04** workflow.
It runs for pull requests and `main` pushes that change the build script,
packaging patch, or workflow, and it can also be triggered manually. Ordinary
HCB application changes do not rebuild libheif.

The workflow builds natively on an Ubuntu 24.04 amd64 runner, verifies every
output against `SHA256SUMS`, and retains the
`libheif-noble-1.23.4-1hcb1-ubuntu24.04.1-amd64` artifact for 90 days, GitHub's
maximum retention for artifacts in public repositories.

The workflow can also be started with GitHub CLI:

```sh
gh workflow run build-libheif-noble.yml --repo hackclub/hcb
```

## Verify the package bundle

[`SHA256SUMS`](SHA256SUMS) contains the checksums for the package bundle used in
production. Verify an extracted bundle from its directory:

```sh
sha256sum -c /path/to/hcb/scripts/libheif/SHA256SUMS
```

The 1.23.4 build completed all 47 upstream test targets successfully. It was
then validated independently by installing these packages together in a fresh
Noble container:

- `libheif1`
- `libheif-plugin-aomdec`
- `libheif-plugin-aomenc`
- `libheif-plugin-libde265`
- `libheif-examples` (diagnostics only)

Both upstream HEIC and AVIF samples decoded through `heif-dec` and Noble's
ImageMagick 6 HEIC coder. ImageMagick loaded
`/usr/lib/x86_64-linux-gnu/libheif.so.1.23.4` from the HCB `libheif1` package.
Determine the production package transaction from the complete
`dpkg-query -W 'libheif*'` output before changing a host.
