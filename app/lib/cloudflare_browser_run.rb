# frozen_string_literal: true

# HTML -> PDF via Cloudflare Browser Run (headless Chrome).
# https://developers.cloudflare.com/browser-rendering/rest-api/pdf-endpoint/
module CloudflareBrowserRun
  FIT_SCALES = [1, 0.9, 0.8, 0.7].freeze

  # fit_to_one_page shrinks a one-page letter until it fits, like wkhtmltopdf's shrink-to-fit did.
  # The letters end with spacer <br>s above their fixed footer, so content that would run into it spills onto a second page instead.
  def self.pdf(html, fit_to_one_page: false)
    return render(html) unless fit_to_one_page

    pdf = nil
    FIT_SCALES.each do |scale|
      pdf = render(html, scale:)
      break if PDF::Reader.new(StringIO.new(pdf)).page_count == 1
    end
    pdf
  end

  def self.render(html, scale: 1)
    connection.post("/client/v4/accounts/#{Credentials.fetch(:CLOUDFLARE, :ACCOUNT_ID)}/browser-rendering/pdf", {
                      html:,
                      # emailed receipts are untrusted HTML, and none of our templates need scripts
                      setJavaScriptEnabled: false,
                      # networkidle0 lets remote images finish loading before printing
                      gotoOptions: { waitUntil: "networkidle0" },
                      # matches the old wkhtmltopdf defaults: US letter, 10mm margins, backgrounds on
                      pdfOptions: { format: "letter", printBackground: true, scale:, margin: { top: "10mm", right: "10mm", bottom: "10mm", left: "10mm" } },
                    }).body
  end
  private_class_method :render

  def self.connection
    Faraday.new(url: "https://api.cloudflare.com") do |f|
      f.request :json
      f.request :authorization, "Bearer", -> { Credentials.fetch(:CLOUDFLARE, :BROWSER_RUN_API_TOKEN) }
      f.response :raise_error
      f.options.timeout = 60
    end
  end
end
