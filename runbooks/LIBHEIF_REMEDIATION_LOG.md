# libheif Production Remediation Log

Remediation date: September 16, 2026

This records the steps used to replace the vulnerable libheif package and
restore HEIF-family processing on HCB's Ubuntu 24.04 LTS (Noble) Hatchbox
hosts. It is a record of the completed production change, not an automated
provisioning mechanism.

## Outcome

We updated these hosts one at a time:

- `server-app-1`
- `server-app-2`
- the jobs server

Every host now has these packages at
`1.23.4-1hcb1~ubuntu24.04.1`:

- `libheif1`
- `libheif-plugin-aomdec`
- `libheif-plugin-aomenc`
- `libheif-plugin-libde265`

On each host, ImageMagick loads
`/usr/lib/x86_64-linux-gnu/libheif.so.1.23.4`, the strukturag PPA is absent,
and HEIC-to-PNG conversion succeeds. The ImageMagick coder denials for `HEIC`,
`HEIF`, `AVIF`, and `AVCI` were removed only after that host passed the direct
decode and linkage checks.

## Starting state

Production was running `1.19.8-1~ppa1~ubuntu24.04` from
`ppa:strukturag/libheif`. That version is affected by
[GHSA-2jg2-4ch7-h545](https://github.com/strukturag/libheif/security/advisories/GHSA-2jg2-4ch7-h545).

[CVE-2026-84383 / GHSA-g89c-p67h-r497](https://github.com/strukturag/libheif/security/advisories/GHSA-g89c-p67h-r497)
was also relevant to the decision to move to the current security release, but
it was not the advisory that directly affected HCB's installed version. Its
vulnerable code was introduced in libheif 1.22.0, after HCB's 1.19.8 package.
GHSA-2jg2-4ch7-h545 separately affects libheif 1.23.1 and earlier, including
1.19.8, and was therefore the direct exposure remediated here. Both advisories
are fixed in the installed 1.23.4 release.

We had mitigated exposure by adding local ImageMagick policies with
`rights="none"` for `HEIC`, `HEIF`, `AVIF`, and `AVCI`. Uploads remained
stored, but previews, image analysis, and OCR could not decode them.

Ubuntu Noble did not provide a fixed libheif package, and Hatchbox runs HCB
directly on its provisioned hosts rather than using the repository's Docker
image. We therefore built Noble-native packages under dpkg control.

## Package build

The package was built once with the checksum-pinned builder now stored in
[`scripts/libheif`](../scripts/libheif). The successful build ran natively on
an Ubuntu 24.04 amd64 GitHub Actions runner and produced the artifact
`libheif-noble-1.23.4-1hcb1-ubuntu24.04.1-amd64`.

The build:

1. downloaded upstream libheif 1.23.4 and Debian 1.23.3 packaging;
2. verified both inputs against pinned SHA-256 checksums;
3. disabled only the optional kvazaar encoder unavailable on Noble;
4. built amd64 source and binary packages in `ubuntu:24.04`;
5. ran all 47 upstream test targets; and
6. emitted `SHA256SUMS` with the package bundle.

We downloaded and extracted the Actions artifact, then verified it before
copying it to any server:

```sh
OUTPUT="$HOME/Downloads/libheif-noble-1.23.4-1hcb1-ubuntu24.04.1-amd64"
(cd "$OUTPUT" && sha256sum -c SHA256SUMS)
```

## Host-by-host rollout

We completed the following sequence on one server before starting the next.
Hosts not yet updated remained protected by their local ImageMagick policy.

### 1. Transfer and verify the bundle

From the machine holding the extracted artifact, we copied the entire bundle:

```sh
SERVER=root@server-app-1
ssh "$SERVER" 'test ! -e /root/libheif-noble-1.23.4'
scp -r "$OUTPUT" "$SERVER:/root/libheif-noble-1.23.4"
ssh "$SERVER"
```

On the server, we set the values used by the remaining commands and verified
the transferred files:

```sh
set -euo pipefail

HCB_VERSION='1.23.4-1hcb1~ubuntu24.04.1'
PPA_VERSION='1.19.8-1~ppa1~ubuntu24.04'
BUNDLE=/root/libheif-noble-1.23.4

cd "$BUNDLE"
sha256sum -c SHA256SUMS
```

### 2. Record the baseline

We confirmed the operating system, installed packages, ImageMagick linkage,
and effective policy:

```sh
. /etc/os-release
printf 'host=%s release=%s codename=%s architecture=%s\n' \
  "$(hostname)" "$VERSION_ID" "$VERSION_CODENAME" \
  "$(dpkg --print-architecture)"

dpkg-query -W \
  -f='${db:Status-Abbrev}\t${binary:Package}\t${Version}\n' \
  'libheif*' | awk '$1 == "ii"'

apt-cache policy libheif1

coder=$(find /usr/lib -type f -path '*ImageMagick*' \
  -name heic.so -print -quit)
printf 'coder=%s\n' "$coder"
test -n "$coder"
ldd "$coder" | grep -E 'libheif|not found'

POLICY=$(find /etc -maxdepth 2 -type f \
  -path '*ImageMagick*/policy.xml' -print -quit)
printf 'policy=%s\n' "$POLICY"
test -n "$POLICY"
convert -list policy
```

The hosts reported Ubuntu 24.04 LTS (Noble) on amd64, the four 1.19.8 PPA
packages, and effective coder denials for all four HEIF-family names.

We created a trusted 64×64 HEIC and confirmed ImageMagick still blocked it:

```sh
printf '%s' 'AAAAHGZ0eXBoZWl4AAAAAG1pZjFoZWl4bWlhZgAAAT9tZXRhAAAAAAAAACFoZGxyAAAAAAAAAABwaWN0AAAAAAAAAAAAAAAAAAAAACJpbG9jAAAAAERAAAEAAQAAAAABYwABAAAAAAAAAB0AAAAjaWluZgAAAAAAAQAAABVpbmZlAgAAAAABAABodmMxAAAAAA5waXRtAAAAAAABAAAAv2lwcnAAAAChaXBjbwAAAHdodmNDAQQIAAAAAAAAAAAAHvAA/P38/AAADwNgAAEAF0ABDAH//wQIAAADAJm4AAADAAAeugJAYQABACtCAQEECAAAAwCZuAAAAwAAHqAggQRSlupJKa5uAhoMCAAAAwDIAAADAAhAYgABAAdEAcFysCJAAAAAFGlzcGUAAAAAAAAAQAAAAEAAAAAOcGl4aQAAAAABDAAAABZpcG1hAAAAAAAAAAEAAQOBAgMAAAAlbWRhdAAAABkoAa8TgOUz5/X//kkKP/9mCzw/siNK1QM/' |
  base64 -d > /tmp/libheif-test.heic

if identify /tmp/libheif-test.heic; then
  echo 'STOP: HEIC unexpectedly decoded while it should be blocked.' >&2
  exit 1
else
  echo 'HEIC is blocked as expected.'
fi
```

### 3. Preserve rollback material

Before changing packages or apt sources, we saved the old package set and the
blocked policy together:

```sh
mkdir -p /root/libheif-rollback
cd /root/libheif-rollback

apt-get download \
  "libheif1=$PPA_VERSION" \
  "libheif-plugin-aomdec=$PPA_VERSION" \
  "libheif-plugin-aomenc=$PPA_VERSION" \
  "libheif-plugin-libde265=$PPA_VERSION"

sha256sum ./*.deb > SHA256SUMS
sha256sum -c SHA256SUMS

cp --archive "$POLICY" \
  /root/libheif-rollback/policy.xml.blocked-before-libheif-1.23.4
```

### 4. Simulate and install the replacement

We first simulated the exact four-package transaction:

```sh
cd "$BUNDLE"

apt install --simulate --no-install-recommends \
  "./libheif1_${HCB_VERSION}_amd64.deb" \
  "./libheif-plugin-aomdec_${HCB_VERSION}_amd64.deb" \
  "./libheif-plugin-aomenc_${HCB_VERSION}_amd64.deb" \
  "./libheif-plugin-libde265_${HCB_VERSION}_amd64.deb"
```

Apt proposed upgrading only those four libheif packages. We then ran the same
transaction without `--simulate`, while the ImageMagick policy remained
blocked:

```sh
apt install --no-install-recommends \
  "./libheif1_${HCB_VERSION}_amd64.deb" \
  "./libheif-plugin-aomdec_${HCB_VERSION}_amd64.deb" \
  "./libheif-plugin-aomenc_${HCB_VERSION}_amd64.deb" \
  "./libheif-plugin-libde265_${HCB_VERSION}_amd64.deb"
```

### 5. Verify packages and runtime linkage

We verified all packages moved together, that dpkg found no modified package
files, and that ImageMagick resolved the new shared library:

```sh
packages=(
  libheif1
  libheif-plugin-aomdec
  libheif-plugin-aomenc
  libheif-plugin-libde265
)

for package in "${packages[@]}"; do
  installed=$(dpkg-query -W -f='${Version}' "$package")
  printf '%s\t%s\n' "$package" "$installed"
  test "$installed" = "$HCB_VERSION"
done

dpkg --verify "${packages[@]}"

library=$(readlink -f /lib/x86_64-linux-gnu/libheif.so.1)
printf 'library=%s\n' "$library"
dpkg-query -S "$library"

coder=$(find /usr/lib -type f -path '*ImageMagick*' \
  -name heic.so -print -quit)
printf 'coder=%s\n' "$coder"
test -n "$coder"
ldd "$coder" | grep -E 'libheif|not found'

test "$library" = /usr/lib/x86_64-linux-gnu/libheif.so.1.23.4
```

The policy still blocked ImageMagick at this point. We installed the diagnostic
package from the same bundle and tested libheif directly:

```sh
cd "$BUNDLE"
apt install --no-install-recommends \
  "./libheif-examples_${HCB_VERSION}_amd64.deb"

heif-info --version
heif-info /tmp/libheif-test.heic
```

`heif-info` reported libheif 1.23.4 and successfully read the trusted HEIC.

### 6. Restore ImageMagick processing

Only after the package and direct-decode checks passed did we inspect and edit
the local policy:

```sh
nl -ba "$POLICY" | grep -B2 -A2 -Ei 'HEIC|HEIF|AVIF|AVCI'
SUDO_EDITOR=vim sudoedit "$POLICY"
convert -list policy
```

We removed only these entries:

```xml
<policy domain="coder" rights="none" pattern="HEIC" />
<policy domain="coder" rights="none" pattern="HEIF" />
<policy domain="coder" rights="none" pattern="AVIF" />
<policy domain="coder" rights="none" pattern="AVCI" />
```

We immediately confirmed both identification and conversion through
ImageMagick:

```sh
identify /tmp/libheif-test.heic
convert /tmp/libheif-test.heic -auto-orient /tmp/libheif-test.png
identify /tmp/libheif-test.png
```

The trusted HEIC was identified as 64×64 and converted successfully. No Rails
restart was required because MiniMagick starts a new ImageMagick process for
each conversion.

### 7. Remove the stale PPA

After all decode checks passed, we removed the strukturag package source:

```sh
add-apt-repository --remove -y ppa:strukturag/libheif

if [[ -e /etc/apt/sources.list.d/strukturag-ubuntu-libheif-noble.sources ]]; then
  mv /etc/apt/sources.list.d/strukturag-ubuntu-libheif-noble.sources \
    /root/strukturag-ubuntu-libheif-noble.sources.removed
fi

apt-get update
apt-cache policy libheif1
grep -RhsE 'strukturag/libheif|ppa\.launchpadcontent\.net/strukturag' \
  /etc/apt/sources.list /etc/apt/sources.list.d || true
```

One host retained the deb822 `.sources` file after
`add-apt-repository --remove`; moving that file out of
`/etc/apt/sources.list.d` removed the source. On all hosts, the final `grep`
printed nothing and apt kept the installed HCB package as its candidate.

We removed the optional diagnostics package and temporary samples after
testing:

```sh
apt purge -y libheif-examples
rm -f /tmp/libheif-test.heic /tmp/libheif-test.png
```

## Post-rollout receipt recovery

The rollout's host-level verification established that the exact library
loaded by ImageMagick could identify and convert a trusted HEIC after the
policy change. We then inventoried HEIF-family receipt files uploaded while the
coder denial was active, from August 27 through September 16, 2026.

Three automatic operations could have failed during that window:

1. `ActiveStorage::AnalyzeJob`, which records image dimensions;
2. `ActiveStorage::TransformJob`, which creates Receipt's tracked,
   preprocessed `1024x1024` variant; and
3. `Receipt::ExtractTextualContentJob`, whose OCR path converts an image to PNG
   before invoking Tesseract.

We ran the following Ruby in a production Rails console to inventory the
affected state and enqueue only the missing work:

```ruby
window = Time.utc(2026, 8, 27)...Time.utc(2026, 9, 17)

content_types = %w[
  image/avif
  image/avif-sequence
  image/heic
  image/heic-sequence
  image/heif
  image/heif-sequence
]

receipts = Receipt
  .joins(file_attachment: :blob)
  .where(created_at: window)
  .where(active_storage_blobs: { content_type: content_types })
  .includes(file_attachment: { blob: :variant_records })
  .to_a

missing_analysis = receipts.select do |receipt|
  metadata = receipt.file.blob.metadata
  metadata["width"].blank? || metadata["height"].blank?
end

missing_variant = receipts.select do |receipt|
  variant = receipt.file.variant(:"1024x1024")

  receipt.file.blob.variant_records.none? do |record|
    record.variation_digest == variant.variation.digest
  end
end

failed_ocr = receipts.select do |receipt|
  receipt.textual_content_ciphertext.present? &&
    receipt.textual_content_source.nil?
end

pp(
  candidates: receipts.size,
  missing_analysis: missing_analysis.size,
  missing_variant: missing_variant.size,
  failed_ocr: failed_ocr.size,
  missing_analysis_ids: missing_analysis.map(&:id),
  missing_variant_ids: missing_variant.map(&:id),
  failed_ocr_ids: failed_ocr.map(&:id)
)

missing_analysis.each do |receipt|
  ActiveStorage::AnalyzeJob.perform_later(receipt.file.blob)
end

missing_variant.each do |receipt|
  ActiveStorage::TransformJob.perform_later(
    receipt.file.blob,
    { resize: "1024x1024" }
  )
end

failed_ocr.each do |receipt|
  Receipt::ExtractTextualContentJob.perform_later(receipt)
end

pp(
  analysis_enqueued: missing_analysis.size,
  variants_enqueued: missing_variant.size,
  ocr_enqueued: failed_ocr.size
)
```

We sanity-checked the recovery on one receipt first: its preview was absent in
the admin view before replay, then rendered after its processing was rerun. We
then replayed all three operations for the remaining receipts in the incident
window.

Replaying these operations was safe for this recovery. Analysis replaces blob
metadata, tracked variant processing reuses an existing successful variant,
and the OCR job skips receipts whose textual content is already present. An
OCR failure during the denial had stored blank text with no source, so those
receipts remained eligible for another OCR attempt.

We intentionally did not replay `Receipt::SuggestPairingsJob`. Suggestions are
a UX convenience rather than required receipt processing, and replaying them
can reset existing pairing-review state or auto-attach an emailed receipt-bin
receipt to a transaction.

## Rollback material retained

Each host retains `/root/libheif-rollback`, containing:

- checksummed 1.19.8 packages for the four previous libheif packages; and
- `policy.xml.blocked-before-libheif-1.23.4`.

Rollback would begin by restoring the blocked policy before downgrading the
packages with `apt install --allow-downgrades --no-install-recommends ./*.deb`.
We did not need to roll back any host.
