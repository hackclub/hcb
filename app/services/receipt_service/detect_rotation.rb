# frozen_string_literal: true

require "open3"

module ReceiptService
  # Works out whether a receipt image was uploaded sideways or upside down.
  #
  # Uses Tesseract's orientation and script detection mode (`--psm 0`), which
  # ships with the `tesseract-ocr` package we already install for OCR. Returns
  # the clockwise rotation in degrees (90, 180 or 270) that would make the text
  # upright, or nil when the image is already upright or Tesseract can't tell.
  class DetectRotation
    # Tesseract's "orientation confidence" is the margin between the best and
    # second best orientation. Clean scans score around 8, blurry or skewed
    # phone photos around 3-5, and guesses on images with too little text
    # fall below 1. Rotating an upright receipt is worse than leaving a
    # sideways one alone, so anything under this is treated as unknown.
    MIN_CONFIDENCE = 2.0

    def initialize(path:)
      @path = path
    end

    def run
      output, status = Open3.capture2e(RTesseract.config.command, @path.to_s, "stdout", "--psm", "0")
      # Tesseract exits non-zero (e.g. "Too few characters") when it can't
      # detect an orientation.
      return nil unless status.success?

      rotate = output[/^Rotate: (\d+)/, 1]&.to_i
      confidence = output[/^Orientation confidence: ([\d.]+)/, 1]&.to_f
      return nil if rotate.nil? || confidence.nil?
      return nil if rotate.zero? || confidence < MIN_CONFIDENCE

      rotate
    end

  end
end
