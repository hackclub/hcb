# frozen_string_literal: true

require "rails_helper"

# Runs real Tesseract and ImageMagick on purpose: what matters is that the two
# agree on which way is clockwise, and that a wrong guess gets caught.
RSpec.describe ReceiptService::DetectRotation do
  let(:upright) { Rails.root.join("spec/fixtures/files/rotation_receipt.png").to_s }
  def turned(degrees)
    # held in an ivar so the tempfile isn't collected mid-example
    @turned = ImageProcessing::MiniMagick.source(upright).rotate(degrees).call
    @turned.path
  end

  def detector(path = upright)
    @detector ||= described_class.new(path:)
  end

  def stub_orientation_guess(output, success: true)
    status = instance_double(Process::Status, success?: success)
    allow(detector).to receive(:tesseract).and_call_original
    allow(detector).to receive(:tesseract).with(anything, "--psm", "0", any_args).and_return([output, status])
  end

  # confident word count by how far the upload is turned
  def stub_confident_words(counts)
    allow(detector).to receive(:confident_words_rotated) { |turn| counts.fetch(turn) }
  end

  { 90 => 270, 180 => 180, 270 => 90 }.each do |applied, fix|
    it "returns #{fix} for a receipt turned #{applied} degrees clockwise" do
      expect(described_class.new(path: turned(applied)).run).to eq(fix)
    end
  end

  it "returns nil when the image is already upright" do
    expect(described_class.new(path: upright).run).to be_nil
  end

  it "returns nil when tesseract confidently proposes a rotation that reads worse" do
    stub_orientation_guess("Rotate: 180\nOrientation confidence: 6.85\n")

    expect(detector.run).to be_nil
    expect(detector).to have_received(:tesseract).with(anything, "--psm", "0", any_args)
  end

  it "accepts a proposal that reads clearly best" do
    stub_orientation_guess("Rotate: 90\n")
    stub_confident_words(0 => 5, 90 => 20, 180 => 3, 270 => 4)

    expect(detector.run).to eq(90)
  end

  it "returns nil when another orientation reads better than the proposed one" do
    stub_orientation_guess("Rotate: 90\n")
    stub_confident_words(0 => 5, 90 => 20, 180 => 30, 270 => 4)

    expect(detector.run).to be_nil
  end

  it "returns nil when the rotated image has too few words" do
    stub_orientation_guess("Rotate: 90\n")
    stub_confident_words(0 => 1, 90 => 9, 180 => 0, 270 => 0)

    expect(detector.run).to be_nil
  end

  it "returns nil when there is too little text to detect an orientation" do
    stub_orientation_guess("Too few characters. Skipping this page\nError during processing.\n", success: false)

    expect(detector(turned(90)).run).to be_nil
  end

  it "raises when tesseract fails for any other reason" do
    stub_orientation_guess("Error opening data file osd.traineddata\n", success: false)

    expect { detector.run }.to raise_error(/orientation detection failed/)
  end

  it "gives up, and kills tesseract, when detection takes too long" do
    stub_const("#{described_class}::TIME_LIMIT", 0.seconds)
    pids = []
    allow(Process).to receive(:kill).and_wrap_original do |original, signal, pid|
      pids << pid
      original.call(signal, pid)
    end

    expect(detector(turned(90)).run).to be_nil
    expect(pids.size).to eq(1)
  end

  it "shrinks large images before detection" do
    stub_const("#{described_class}::MAX_SIDE", 300)
    sizes = []
    allow(detector).to receive(:tesseract).and_wrap_original do |original, path, *args|
      sizes << MiniMagick::Image.open(path).dimensions
      original.call(path, *args)
    end

    detector.run

    expect(sizes.flatten.max).to eq(300)
  end
end
