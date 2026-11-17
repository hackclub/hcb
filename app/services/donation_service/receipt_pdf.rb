# frozen_string_literal: true

module DonationService
  class ReceiptPdf
    def initialize(donation:)
      @donation = donation
    end

    def run
      html = ApplicationController.render(
        template: "donations/receipt", formats: [:pdf], layout: false,
        assigns: { donation: @donation }
      )
      footer = ApplicationController.render(
        template: "donations/receipt_footer", formats: [:pdf], layout: false
      )

      WickedPdf.new.pdf_from_string(
        html, encoding: "UTF-8", page_height: "11in", page_width: "8.5in",
        margin: { bottom: 20 }, footer: { content: footer }
      )
    end

  end
end
