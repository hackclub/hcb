# frozen_string_literal: true

require "open3"

module ReceiptService
  # Works out whether a receipt image was uploaded sideways or upside down.
  #
  # Tesseract's orientation and script detection mode (`--psm 0`), which ships
  # with the `tesseract-ocr` package we already install for OCR, proposes a
  # rotation. Its guess is only a proposal: it is often wrong on receipts, and
  # its confidence score doesn't tell you when (upright dot-matrix receipts get
  # called upside down with high confidence). So we rotate only if OCR reads
  # the rotated image clearly better than the upload.
  #
  # Returns the clockwise rotation in degrees (90, 180 or 270) that makes the
  # text upright, or nil when the image is upright or we aren't sure.
  class DetectRotation
    # Tuned on 205 public receipts (scans and phone photos) and checked on 204
    # held-out ones, each at all four orientations. Held-out result: 77% of
    # turned scans and 16% of turned (small, blurry) phone photos fixed, none
    # made worse. Missing a sideways receipt is fine; rotating a good one isn't.
    #
    # A wrongly oriented receipt still OCRs to a few "confident" words by
    # chance: usually under 10 on photos, but up to ~60 on dense scans. Hence
    # both a floor and a ratio.
    MIN_WORDS = 10
    MIN_IMPROVEMENT = 2

    def initialize(path:)
      @path = path
    end

    def run
      output, status = Open3.capture2e(RTesseract.config.command, @path.to_s, "stdout", "--psm", "0")
      # Tesseract exits non-zero (e.g. "Too few characters") when it can't
      # detect an orientation.
      return nil unless status.success?

      rotate = output[/^Rotate: (\d+)/, 1].to_i
      return nil if rotate.zero?

      rotate if reads_better_rotated?(rotate)
    end

    private

    def reads_better_rotated?(degrees)
      rotated = ImageProcessing::MiniMagick.source(@path.to_s).rotate(degrees).call
      before = confident_words(@path)
      after = confident_words(rotated.path)

      after >= MIN_WORDS && after >= before * MIN_IMPROVEMENT
    end

    # `psm: 6` treats the image as one upright block of text. The default mode
    # quietly reads sideways text, which would hide the difference.
    def confident_words(path)
      RTesseract.new(path.to_s, psm: 6).to_box.count { |w| w[:confidence] > 85 }
    end

  end
end
