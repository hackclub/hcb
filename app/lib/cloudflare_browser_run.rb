# frozen_string_literal: true

# HTML -> PDF via Cloudflare Browser Run (headless Chrome).
# https://developers.cloudflare.com/browser-rendering/rest-api/pdf-endpoint/
module CloudflareBrowserRun
  def self.pdf(html)
    connection.post("/client/v4/accounts/#{Credentials.fetch(:CLOUDFLARE, :ACCOUNT_ID)}/browser-rendering/pdf", {
                      html:,
                      # emailed receipts are untrusted HTML, and none of our templates need scripts
                      setJavaScriptEnabled: false,
                      # networkidle0 lets remote images finish loading before printing
                      gotoOptions: { waitUntil: "networkidle0" },
                      # matches the old wkhtmltopdf defaults: US letter, 10mm margins, backgrounds on
                      pdfOptions: { format: "letter", printBackground: true, margin: { top: "10mm", right: "10mm", bottom: "10mm", left: "10mm" } },
                    }).body
  end

  def self.connection
    Faraday.new(url: "https://api.cloudflare.com") do |f|
      f.request :json
      f.request :authorization, "Bearer", -> { Credentials.fetch(:CLOUDFLARE, :BROWSER_RUN_API_TOKEN) }
      f.response :raise_error
      f.options.timeout = 60
    end
  end
end
