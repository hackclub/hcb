---
name: csv-preview
description: Add CSV and TSV previews and thumbnails to Active Storage attachments in a Rails app, or render a CSV file as a PNG, JPEG or WebP image in Ruby, using the csv_preview gem. Use when CSV attachments show no thumbnail, when preview or representation raises ActiveStorage::UnpreviewableError or UnrepresentableError for text/csv, or when someone wants a picture of a CSV table without LibreOffice, a headless browser or ImageMagick.
license: MIT
compatibility: Ruby 3.3+, libvips 8.12+ with Pango; Rails 7.2+ for the Active Storage previewer.
---

# Add csv_preview to an app

csv_preview is a Ruby gem that renders CSV and TSV files as preview images (PNG, JPEG or WebP) and adds an Active Storage previewer to Rails. Beautiful CSV previews for Active Storage. No LibreOffice, no headless browser, no network. Built for untrusted uploads: it reads at most 2 MiB, stops after 5 seconds, and never runs another program or opens a network connection.

Follow the steps in order. The README beside this directory in the installed gem (`bundle info --path csv_preview`) has the details; online at https://github.com/garyhtou/csv_preview.

## 1. When not to use it

- XLSX, ODS, Numbers or other spreadsheet files: csv_preview reads CSV and TSV text only and raises `CsvPreview::UnreadableInput` for them. Use a LibreOffice-based previewer (such as activestorage-office-previewer) for Office files; it can be registered alongside csv_preview.
- Rendering a whole file: previews show the first rows (20 by default) and up to 12 columns.
- Dark images: previews are light, inside a bordered frame.

## 2. Check the environment

- Ruby 3.3 or newer, and Rails 7.2 or newer for the previewer: read `Gemfile.lock` (`RUBY VERSION`, `activestorage`).
- Find the attachments that hold CSV files: `grep -rn "has_one_attached\|has_many_attached" app/models`.
- Find the variant processor: `config.active_storage.variant_processor` in `config/`; without it, apps on `load_defaults 7.0` or newer use `:vips`.
- Find where the app is built and deployed (a `Dockerfile`, server provisioning): libvips is needed there, not only on the development machine.

## 3. Install

```sh
bundle add csv_preview
```

System packages, wherever the app runs:

```sh
# Debian and Ubuntu (Rails' generated Dockerfile already installs libvips when Active Storage is enabled)
apt-get install --no-install-recommends libvips
# Optional, for colour emoji, Chinese, Japanese and Korean, and scripts such as Thai and Hindi;
# then run fc-cache -f in images
apt-get install --no-install-recommends fontconfig fonts-noto-color-emoji fonts-noto-cjk fonts-noto-core
# macOS
brew install vips
```

## 4. Verify text support

```sh
bin/rails runner 'p CsvPreview.text_supported?'
```

It must print `true`. If it prints `false` or fails, libvips is missing or was built without Pango: fix the installation before going on. Do not work around it; without text support CSV files are simply not previewable.

## 5. Register the previewer, exactly once

In `config/application.rb`, inside the `Application` class:

```ruby
config.active_storage.previewers.unshift CsvPreview::ActiveStoragePreviewer
```

`unshift` puts csv_preview first, so it wins over any other previewer that accepts `text/csv`. The equivalent setting, if the app prefers settings:

```ruby
config.csv_preview.register_previewer = true
```

Use one of the two. If the Gemfile has `require: false` for csv_preview, add `require "csv_preview"` at the top of `config/application.rb`.

## 6. Discard files that cannot be previewed

A file labelled `text/csv` can still be binary. csv_preview then raises, the previewer raises `ActiveStorage::PreviewError`, and Active Storage's jobs would retry it. Create `config/initializers/csv_preview.rb`:

```ruby
Rails.application.config.to_prepare do
  ActiveStorage::PreviewImageJob.discard_on ActiveStorage::PreviewError
  ActiveStorage::TransformJob.discard_on ActiveStorage::PreviewError
end
```

`to_prepare` is required: the job classes are reloaded in development.

## 7. Views and thumbnails

Always guard with `representable?`; it is false for files without a previewer and on hosts without text support.

```erb
<%= image_tag document.file.representation(resize_to_limit: [800, 800]) if document.file.representable? %>
```

For thumbnails, crop to the top-left corner so the header survives. A centred crop of a wide table shows nothing useful.

```ruby
has_one_attached :file do |attachable|
  # libvips (Rails' default variant processor)
  attachable.variant :thumb, resize_to_fill: [300, 300, { crop: :low }], preprocessed: true
  # MiniMagick: resize_to_fill: [300, 300, { gravity: "NorthWest" }]
end
```

```erb
<%= image_tag document.file.representation(:thumb) if document.file.representable? %>
```

`preprocessed: true` renders the preview in a background job right after upload. If the attachment also holds photos, add a separate CSV-only variant and choose it in the view:

```ruby
attachable.variant :table_thumb, resize_to_fill: [300, 300, { crop: :low }],
  preprocessed: ->(record) { CsvPreview::ActiveStoragePreviewer.accept?(record.file.blob) }
```

Global options go in the initializer from step 6, outside the `to_prepare` block:

```ruby
CsvPreview.configure do |config|
  config.max_rows = 12
  config.previewer_content_types += %w[text/x-csv application/csv]
end
```

## 8. Test it

Adapt the model and attachment names to the app:

```ruby
# test/models/csv_preview_test.rb
require "test_helper"

class CsvPreviewTest < ActiveSupport::TestCase
  test "CSV attachments are previewable" do
    assert CsvPreview.text_supported?, "libvips cannot draw text; see the csv_preview README, Installation"

    document = Document.create!(file: { io: StringIO.new("Item,Amount\nCoffee,4.50\n"),
                                        filename: "items.csv", content_type: "text/csv" })

    assert document.file.previewable?
    document.file.preview(resize_to_limit: [300, 300]).processed
    assert document.file.blob.preview_image.attached?
  end
end
```

Then run the app's test command (`bin/rails test`, or the RSpec equivalent) and a smoke check that writes an image you can open:

```sh
bin/rails runner 'File.binwrite("tmp/csv_preview_check.png", CsvPreview.render(StringIO.new("Item,Amount\nCoffee,4.50\n")))'
```

## 9. Pitfalls

- Do not pass user-supplied text to `CsvPreview.render` as a String: a String is always a file path. Wrap CSV text in `StringIO.new(text)`.
- Do not add `application/vnd.ms-excel` to `previewer_content_types`: it is the type of binary XLS workbooks. The README has a subclass that accepts it only for `.csv` filenames.
- Do not install LibreOffice, ImageMagick or a headless browser for CSV previews; csv_preview needs none of them.
- Do not register the previewer twice, or append it with `<<` when another previewer accepts `text/csv` (the first one that accepts a file wins).
- Do not expect existing preview images to change after an upgrade: purge and reprocess them (`blob.preview_image.purge`, then `blob.preview({}).processed`).
- Do not require the gem lazily inside a request: on macOS it must load before anything draws text, and the setting from step 5 is ignored when the gem loads after boot.
- Do not call `representation` without checking `representable?`, and do not use `resize_to_fill` without `crop: :low` (or `gravity: "NorthWest"`) for CSV thumbnails.

## 10. Plain Ruby

```ruby
require "csv_preview"
File.binwrite("orders.png", CsvPreview.render("orders.csv"))
```

`CsvPreview.render(path_or_io, **options)` returns image bytes; `format: :jpeg` or `format: :webp` changes the format. `CsvPreview.sample(path_or_io)` returns the cleaned cells without rendering. Rescue `CsvPreview::UnreadableInput` (not CSV text) and `CsvPreview::TimeoutExceeded` to show a fallback.

## Links

- README sections: Installation, Rails usage, Plain Ruby usage, Options, Security and FAQ, in `README.md` of the installed gem or at https://github.com/garyhtou/csv_preview
- Security policy: `SECURITY.md` in the installed gem
- API reference: https://rubydoc.info/gems/csv_preview
