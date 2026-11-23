# frozen_string_literal: true

# CSV previews (see CsvPreview::ActiveStoragePreviewer in config/application.rb) show the first 20
# rows. 256 KiB is plenty for that, and it bounds the ranged read of each preview attempt: a failed
# preview isn't cached by Active Storage, so a junk file labelled text/csv is re-read on later views.
# Larger files are still previewed; the footer just can't give their total row count.
CsvPreview.configure do |config|
  config.max_input_bytes = 256.kilobytes
end
