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
    # Checked on a sample of 152 real receipt uploads, each as uploaded and
    # turned 90, 180 and 270 degrees: 69% of turned copies fixed, and no
    # upright receipt touched. Missing a sideways receipt is fine; rotating a
    # good one isn't.
    #
    # A wrongly oriented receipt still OCRs to some "confident" words by
    # chance: about 10 on a typical receipt and up to ~80 on a dense one,
    # against about 60 the right way up. Hence both a floor and a ratio.
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
      before = confident_words(@path)
      after = confident_words_rotated(degrees)
      return false unless after >= MIN_WORDS && after >= before * MIN_IMPROVEMENT

      # It must also beat the other two orientations, or we could turn a
      # sideways receipt upside down. Only costs extra OCR when we're about
      # to rotate, which is rare.
      ([90, 180, 270] - [degrees]).all? { |other| after > confident_words_rotated(other) }
    end

    def confident_words_rotated(degrees)
      rotated = ImageProcessing::MiniMagick.source(@path.to_s).rotate(degrees).call
      confident_words(rotated.path)
    end

    # `psm: 6` treats the image as one upright block of text. The default mode
    # quietly reads sideways text, which would hide the difference.
    def confident_words(path)
      RTesseract.new(path.to_s, psm: 6).to_box.count { |w| w[:confidence] > 85 }
    end

  end
end
