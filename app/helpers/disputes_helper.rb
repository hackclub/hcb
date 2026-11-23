# frozen_string_literal: true

require "cgi"

module DisputesHelper
  # The form's "Transaction Code" takes an HCB code's hashid. A ledger item has
  # no code ops could look up, so its page's link goes there instead. Pass
  # exactly one of the two.
  def disputed_transactions_airtable_form_url(hcb_code: nil, ledger_item: nil, user: nil, embed: false)
    raise ArgumentError, "pass either hcb_code or ledger_item, not both" if hcb_code && ledger_item
    raise ArgumentError, "pass hcb_code or ledger_item" if hcb_code.nil? && ledger_item.nil?

    # The airtable form is located within the Bank Promotions base
    form_id = "7dq8JWC4Fsus"
    embed_url = "https://forms.hackclub.com/t/#{form_id}"
    url = "https://forms.hackclub.com/t/#{form_id}"

    prefill = []
    prefill << "prefill_Your+Name=#{CGI.escape(user.name)}" if user
    prefill << "prefill_Login+Email=#{CGI.escape(user.email)}" if user
    prefill << "prefill_Transaction+Code=#{CGI.escape(hcb_code ? hcb_code.hashid : ledger_item_url(ledger_item))}"

    "#{embed ? embed_url : url}?#{prefill.join("&")}"
  end

end
