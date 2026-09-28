#!/usr/bin/env bash

set -euo pipefail

readonly PACKAGE_VERSION=1.23.4-1hcb1~ubuntu24.04.1
readonly DEBIAN_BASE_URL=https://deb.debian.org/debian/pool/main/libh/libheif
readonly UPSTREAM_URL=https://github.com/strukturag/libheif/releases/download/v1.23.4/libheif-1.23.4.tar.gz
readonly SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly OUTPUT_DIR=${1:-"$PWD/libheif-noble"}
readonly BUILD_JOBS=${LIBHEIF_BUILD_JOBS:-2}
readonly HOST_UID=$(id -u)
readonly HOST_GID=$(id -g)

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v docker >/dev/null || { echo "Docker is required" >&2; exit 1; }
[[ $BUILD_JOBS =~ ^[1-9][0-9]*$ ]] || {
  echo "LIBHEIF_BUILD_JOBS must be a positive integer" >&2
  exit 1
}

workdir=$(mktemp -d)
cleanup() {
  local status=$?

  if ! rm -rf "$workdir" 2>/dev/null; then
    docker run --rm --volume "$workdir:/work" ubuntu:24.04 \
      find /work -mindepth 1 -delete >/dev/null 2>&1 || true
    rm -rf "$workdir" 2>/dev/null || true
  fi

  return "$status"
}
trap cleanup EXIT
mkdir -p "$OUTPUT_DIR"
if find "$OUTPUT_DIR" -mindepth 1 -print -quit | grep -q .; then
  echo "Output directory must be empty: $OUTPUT_DIR" >&2
  exit 1
fi

docker_args=(
  --rm
  --interactive
  --platform linux/amd64
  --env "DEB_BUILD_OPTIONS=parallel=$BUILD_JOBS"
  --env "HOST_UID=$HOST_UID"
  --env "HOST_GID=$HOST_GID"
)
if [[ -n ${LIBHEIF_DOCKER_NETWORK:-} ]]; then
  docker_args+=(--network "$LIBHEIF_DOCKER_NETWORK")
fi

curl --fail --location --silent --show-error \
  "$UPSTREAM_URL" --output "$workdir/libheif_1.23.4.orig.tar.gz"
curl --fail --location --silent --show-error \
  "$DEBIAN_BASE_URL/libheif_1.23.3-1.debian.tar.xz" \
  --output "$workdir/libheif_1.23.3-1.debian.tar.xz"

cat > "$workdir/SHA256SUMS.inputs" <<'CHECKSUMS'
d0c02b4b0e978f34a1974b6f3eea7975a537bf7a9195ffeea38e7242ff316fdd  libheif_1.23.4.orig.tar.gz
9f41f861b576ee6ef77f4d20924b240f76d9d86845b604526be90be3168f39da  libheif_1.23.3-1.debian.tar.xz
CHECKSUMS
(
  cd "$workdir"
  sha256sum -c SHA256SUMS.inputs
)

docker run "${docker_args[@]}" \
  --volume "$workdir:/work" \
  --volume "$SCRIPT_DIR/noble.patch:/noble.patch:ro" \
  --volume "$(realpath "$OUTPUT_DIR"):/out" \
  ubuntu:24.04 bash -euxo pipefail <<'BUILD'
sed -i \
  's|http://archive.ubuntu.com/ubuntu|http://azure.archive.ubuntu.com/ubuntu|; s|http://security.ubuntu.com/ubuntu|http://azure.archive.ubuntu.com/ubuntu|' \
  /etc/apt/sources.list.d/ubuntu.sources
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends dpkg-dev patch
cd /work
tar -xzf libheif_1.23.4.orig.tar.gz
tar -xJf libheif_1.23.3-1.debian.tar.xz --directory=libheif-1.23.4
cd libheif-1.23.4
patch --strip=1 < /noble.patch
apt-get build-dep -y --no-install-recommends .
dpkg-buildpackage -us -uc
cd /work
cp -v \
  libheif_1.23.4.orig.tar.gz \
  libheif_1.23.4-1hcb1~ubuntu24.04.1* \
  libheif-examples_1.23.4-1hcb1~ubuntu24.04.1_amd64.deb \
  libheif1_1.23.4-1hcb1~ubuntu24.04.1_amd64.deb \
  libheif-plugin-*_1.23.4-1hcb1~ubuntu24.04.1_amd64.deb \
  /out/
chown -R "$HOST_UID:$HOST_GID" /work /out
BUILD

(
  cd "$OUTPUT_DIR"
  sha256sum ./* > SHA256SUMS
)

echo "Built libheif $PACKAGE_VERSION for Noble in $OUTPUT_DIR"
