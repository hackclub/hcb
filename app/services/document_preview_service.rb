# frozen_string_literal: true

class DocumentPreviewService
  def initialize(type:, event:, contract_signers: nil, ach_transfer: nil, disbursement: nil)
    @type = type
    @event = event
    @contract_signers = contract_signers
    @ach_transfer = ach_transfer
    @disbursement = disbursement
  end

  def run
    IO.popen(cmd, err: File::NULL).read
  end

  private

  def pdf_string
    @pdf_string ||= CloudflareBrowserRun.pdf(html, fit_to_one_page: true)
  end

  def html
    # ApplicationController's renderer brings in the app helpers (e.g. pdf_asset_base64)
    ApplicationController.render(
      template: template_path, formats: :pdf, layout: false,
      assigns: { event: @event, contract_signers: @contract_signers, ach_transfer: @ach_transfer, disbursement: @disbursement }.compact
    )
  end

  def template_path
    case @type
    when :verification_letter then "documents/verification_letter"
    when :fiscal_sponsorship_letter then "documents/fiscal_sponsorship_letter"
    when :ach_transfer_confirmation then "ach_transfers/transfer_confirmation_letter"
    when :disbursement_confirmation then "disbursements/transfer_confirmation_letter"
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

  def cmd
    ["pdftoppm", "-singlefile", "-r", "72", "-png", input.path]
  end

end
