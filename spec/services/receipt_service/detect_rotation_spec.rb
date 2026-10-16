# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptService::DetectRotation do
  subject(:rotation) { described_class.new(path: "/tmp/receipt.png").run }

  def stub_tesseract(output, success: true)
    status = instance_double(Process::Status, success?: success)
    allow(Open3).to receive(:capture2e)
      .with("tesseract", "/tmp/receipt.png", "stdout", "--psm", "0")
      .and_return([output, status])
  end

  def osd_output(rotate:, confidence:)
    <<~OUTPUT
      Page number: 0
      Orientation in degrees: #{(360 - rotate) % 360}
      Rotate: #{rotate}
      Orientation confidence: #{confidence}
      Script: Latin
      Script confidence: 2.13
    OUTPUT
  end

  it "returns the clockwise rotation needed to make the text upright" do
    stub_tesseract(osd_output(rotate: 270, confidence: 8.35))
    expect(rotation).to eq(270)
  end

  it "returns nil when the image is already upright" do
    stub_tesseract(osd_output(rotate: 0, confidence: 8.04))
    expect(rotation).to be_nil
  end

  it "returns nil when tesseract isn't confident" do
    stub_tesseract(osd_output(rotate: 270, confidence: 0.63))
    expect(rotation).to be_nil
  end

  it "returns nil when tesseract can't detect an orientation" do
    stub_tesseract("Too few characters. Skipping this page\nError during processing.\n", success: false)
    expect(rotation).to be_nil
  end

  it "returns nil when the output is missing the fields we need" do
    stub_tesseract("Page number: 0\n")
    expect(rotation).to be_nil
  end
end
