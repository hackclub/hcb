# frozen_string_literal: true

class DocumentPreviewService
  def initialize(type:, event:, contract_signers: nil, ach_transfer: nil, disbursement: nil)
    @type = type
    @event = event
    @contract_signers = contract_signers
    @ach_transfer = ach_transfer
    @disbursement = disbursement
  end

  # Renders the first page of the generated PDF to a PNG with libvips, which
  # doesn't need Poppler's `pdftoppm` binary (unavailable on Laravel Cloud).
  def run
    require "vips"

    image = Vips::Image.pdfload(input.path, page: 0, dpi: 72)
    image = image.flatten(background: 255) if image.has_alpha?
    image.write_to_buffer(".png")
  end

  private

  def pdf_string
    @pdf_string ||= ActionController::Base.new.tap do |c|
      c.instance_variable_set(:@event, @event)
      c.instance_variable_set(:@contract_signers, @contract_signers) if @contract_signers
      c.instance_variable_set(:@ach_transfer, @ach_transfer) if @ach_transfer
      c.instance_variable_set(:@disbursement, @disbursement) if @disbursement
    end.render_to_string pdf: template_name, template: template_path, encoding: "UTF-8", formats: :pdf
  end

  def template_name
    case @type
    when :verification_letter then "verification_letter"
    when :fiscal_sponsorship_letter then "fiscal_sponsorship_letter"
    when :ach_transfer_confirmation then "transfer_confirmation_letter"
    when :disbursement_confirmation then "transfer_confirmation_letter"
    else raise "Unknown document type"
    end
  end

  def template_path
    case @type
    when :verification_letter then "documents/verification_letter"
    when :fiscal_sponsorship_letter then "documents/fiscal_sponsorship_letter"
    when :ach_transfer_confirmation then "ach_transfers/transfer_confirmation_letter"
    when :disbursement_confirmation then "disbursement/transfer_confirmation_letter"
    else raise "Unknown document type"
    end
  end

  def input
    @input ||= begin
      input = Tempfile.new(["#{@type}_preview", ".pdf"])
      input.binmode
      input.write(pdf_string)
      input.rewind

      input
    end
  end

end
