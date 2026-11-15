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

    # Tesseract's run time grows with pixel count (a 12 megapixel photo took
    # ~40s), so detection runs on a copy no bigger than this on its long side.
    MAX_SIDE = 2000

    # Detection runs while the upload request waits, so it gets a hard time
    # limit. An upright receipt takes 1-3 seconds, a turned one a few more;
    # out of time means "not sure".
    TIME_LIMIT = 15.seconds
    OutOfTime = Class.new(StandardError)

    def initialize(path:)
      @path = path
    end

    def run
      @deadline = TIME_LIMIT.from_now
      # image_processing applies the EXIF orientation on load
      @image = ImageProcessing::MiniMagick.source(@path.to_s).resize_to_limit(MAX_SIDE, MAX_SIDE).convert("png").call

      output, status = tesseract(@image.path, "--psm", "0")
      return nil if output.include?("Too few characters")
      # Anything else (e.g. missing orientation data file) means detection is
      # broken, which we want to hear about rather than silently never rotate.
      raise "tesseract orientation detection failed: #{output.truncate(200)}" unless status.success?

      rotate = output[/^Rotate: (\d+)/, 1].to_i
      return nil if rotate.zero?

      rotate if reads_better_rotated?(rotate)
    rescue OutOfTime
      nil
    end

    private

    def reads_better_rotated?(degrees)
      # OCR all four orientations at once. Each is its own process, so this
      # takes about as long as the slowest one. It only happens when Tesseract
      # proposes a rotation, which is rare.
      threads = [0, 90, 180, 270].index_with do |turn|
        Thread.new { confident_words_rotated(turn) }.tap { |thread| thread.report_on_exception = false } # `value` re-raises
      end
      words = threads.transform_values(&:value)
      after = words[degrees]

      # It must beat the upload clearly, and also the other two orientations,
      # or we could turn a sideways receipt upside down.
      after >= MIN_WORDS && after >= words[0] * MIN_IMPROVEMENT && words.except(0, degrees).values.all? { |other| after > other }
    end

    def confident_words_rotated(degrees)
      return confident_words(@image.path) if degrees.zero?

      rotated = ImageProcessing::MiniMagick.source(@image.path).rotate(degrees).call
      confident_words(rotated.path)
    end

    # `--psm 6` treats the image as one upright block of text. The default mode
    # quietly reads sideways text, which would hide the difference.
    def confident_words(path)
      output, = tesseract(path, "--psm", "6", "tsv")
      # TSV columns: level (5 = word) is first, confidence and text are last
      output.lines.count do |line|
        columns = line.chomp.split("\t")
        columns[0] == "5" && columns[10].to_f > 85 && columns[11].present?
      end
    end

    # Runs tesseract and returns [output, status], killing it at the deadline.
    def tesseract(path, *args)
      Open3.popen2e(RTesseract.config.command, path.to_s, "stdout", *args) do |_stdin, out, process|
        output = Thread.new { out.read }
        unless process.join([@deadline - Time.current, 0].max)
          Process.kill("KILL", process.pid)
          output.join # the pipe closes once the process is dead
          raise OutOfTime
        end

        [output.value, process.value]
      end
    end

  end
end
