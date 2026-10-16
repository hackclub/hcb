# frozen_string_literal: true

require "rails_helper"

RSpec.describe ConfigurationIntegrity::Taxbandits::MaskedTinCheckJob do
  before { ActionMailer::Base.deliveries.clear }

  let(:submission) { { "FormType" => "FormW9", "FormW9" => { "FormData" => { "TIN" => "XXX-XX-6789" } } } }

  # Builds a minimal one-page PDF with the given page text and, optionally, a
  # form field holding field_value (a raw PDF string literal, e.g. "(123)").
  def build_pdf(text:, field_value: nil, extra_objects: [])
    content = "BT /F1 12 Tf 72 720 Td (#{text}) Tj ET"
    annots = field_value ? " /Annots [5 0 R]" : ""
    objects = [
      "<< /Type /Catalog /Pages 2 0 R#{" /AcroForm << /Fields [5 0 R] >>" if field_value} >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R " \
      "/Resources << /Font << /F1 6 0 R >> >>#{annots} >>",
      "<< /Length #{content.bytesize} >>\nstream\n#{content}\nendstream",
      "<< /Type /Annot /Subtype /Widget /FT /Tx /T (TIN) /V #{field_value || "()"} /Rect [0 0 0 0] /P 3 0 R >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      *extra_objects
    ]

    pdf = +"%PDF-1.4\n"
    offsets = objects.each_with_index.map do |object, i|
      offset = pdf.bytesize
      pdf << "#{i + 1} 0 obj\n#{object}\nendobj\n"
      offset
    end

    xref = pdf.bytesize
    pdf << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
    offsets.each { |offset| pdf << format("%010d 00000 n \n", offset) }
    pdf << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
  end

  def with_dummy_form(id: "tfm_dummy", tin: "123-45-6789")
    allow(Credentials).to receive(:fetch).and_call_original
    allow(Credentials).to receive(:fetch).with(:TAXBANDITS_DUMMY_FORM_ID).and_return(id)
    allow(Credentials).to receive(:fetch).with(:TAXBANDITS_DUMMY_TIN).and_return(tin)
  end

  def with_dummy_pdf(pdf)
    with_dummy_form
    allow(TaxbanditsService).to receive(:get_submission).with("tfm_dummy").and_return(submission)
    allow(Tax::Form).to receive(:taxbandits_pdf).with(submission).and_return(pdf)
  end

  def sent_emails
    ActionMailer::Base.deliveries
  end

  def expect_leak_email
    described_class.perform_now

    expect(sent_emails.map(&:subject)).to eq(["[URGENT] TaxBandits leaking full TINs"])
    expect(sent_emails.first.to).to eq(["hcb-engr@hackclub.com"])
    expect(sent_emails.first.body.encoded).to include("tfm_dummy")
    expect(sent_emails.first.body.encoded).not_to include("6789")
  end

  def expect_all_clear
    described_class.perform_now

    expect(sent_emails).to be_empty
  end

  def expect_couldnt_run_email(reason)
    described_class.perform_now

    expect(sent_emails.map(&:subject)).to eq(["Configuration integrity check couldn't run: #{described_class.name}"])
    expect(sent_emails.first.to).to eq(["hcb-engr@hackclub.com"])
    expect(sent_emails.first.body.encoded).to include(reason, "tfm_dummy")
  end

  it "does nothing unless both the dummy form and its TIN are configured" do
    expect(TaxbanditsService).not_to receive(:get_submission)

    with_dummy_form(id: nil)
    described_class.perform_now

    with_dummy_form(tin: nil)
    described_class.perform_now
  end

  it "sends nothing while the TIN is masked" do
    with_dummy_pdf(build_pdf(text: "TIN: XXX-XX-6789", field_value: "(XXXXX6789)"))
    expect_all_clear
  end

  it "emails engineering about a TIN in the PDF's text, without repeating it" do
    with_dummy_pdf(build_pdf(text: "TIN: 123-45-6789"))
    expect_leak_email
  end

  it "emails about a TIN in a form field" do
    with_dummy_pdf(build_pdf(text: "TIN: XXX-XX-6789", field_value: "(123456789)"))
    expect_leak_email
  end

  it "emails about a TIN in a UTF-16 form field" do
    with_dummy_pdf(build_pdf(text: "TIN: XXX-XX-6789", field_value: "<FEFF#{"123456789".encode("UTF-16BE").unpack1("H*")}>"))
    expect_leak_email
  end

  # How TaxBandits' W-9 lays out an SSN: one field per digit, not in order.
  it "emails about a TIN split one digit per form field" do
    fields = [0, 3, 1, 2, 4, 5, 6, 7, 8].map { |i| "<< /FT /Tx /T (txtSSN#{i}) /V (#{i + 1}) >>" }
    with_dummy_pdf(build_pdf(text: "TIN:", extra_objects: fields))
    expect_leak_email
  end

  it "sends nothing with only the last four digits in per-digit fields" do
    fields = (0..8).map { |i| "<< /FT /Tx /T (txtSSN#{i}) /V (#{i >= 5 ? i + 1 : "X"}) >>" }
    with_dummy_pdf(build_pdf(text: "TIN:", extra_objects: fields))
    expect_all_clear
  end

  # What pdf-reader makes of the cross-reference streams in TaxBandits' PDFs.
  it "skips a cross-reference stream it can't decode" do
    xref_stream = "<< /Type /XRef /Filter /FlateDecode /Length 9 >>\nstream\nnot zlib!\nendstream"
    with_dummy_pdf(build_pdf(text: "TIN: XXX-XX-6789", extra_objects: [xref_stream]))
    expect_all_clear
  end

  it "emails that it couldn't run when another stream can't be decoded" do
    broken_stream = "<< /Filter /FlateDecode /Length 9 >>\nstream\nnot zlib!\nendstream"
    with_dummy_pdf(build_pdf(text: "TIN: XXX-XX-6789", extra_objects: [broken_stream]))
    expect_couldnt_run_email("read the dummy W-9")
  end

  it "emails that it couldn't run when the PDF can't be parsed" do
    with_dummy_pdf("not a pdf")
    expect_couldnt_run_email("read the dummy W-9")
  end

  it "emails that it couldn't run when TaxBandits has no PDF to check" do
    with_dummy_pdf(nil)
    expect_couldnt_run_email("TaxBandits has no PDF")
  end
end
