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

  def stub_orientation_guess(output, success: true)
    status = instance_double(Process::Status, success?: success)
    allow(Open3).to receive(:capture2e).and_call_original
    allow(Open3).to receive(:capture2e)
      .with("tesseract", upright, "stdout", "--psm", "0")
      .and_return([output, status])
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
    expect(described_class.new(path: upright).run).to be_nil
  end

  it "returns nil when tesseract can't detect an orientation" do
    stub_orientation_guess("Too few characters. Skipping this page\nError during processing.\n", success: false)
    expect(described_class.new(path: upright).run).to be_nil
  end

  it "returns nil when the output has no rotation" do
    stub_orientation_guess("Page number: 0\n")
    expect(described_class.new(path: upright).run).to be_nil
  end
end
