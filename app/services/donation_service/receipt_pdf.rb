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

      CloudflareBrowserRun.pdf(html)
    end

  end
end
