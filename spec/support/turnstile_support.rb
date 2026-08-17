# frozen_string_literal: true

# Helpers for specs that cross the Turnstile gate. `Credentials.fetch` prefers
# ENV, so a machine with real `TURNSTILE__*` keys loaded would otherwise flip
# the gate on under specs that never asked for it — stub the keys explicitly in
# whichever direction the spec needs.
module TurnstileSupport
  def enable_turnstile!(site_key: "0x0000site", secret_key: "0x0000secret")
    allow(TurnstileService).to receive_messages(site_key:, secret_key:)
  end

  def disable_turnstile!
    allow(TurnstileService).to receive_messages(site_key: nil, secret_key: nil)
  end

  # Stubs Cloudflare's siteverify endpoint with a canned verdict. The defaults
  # suit the login widget in a request spec; pass `action:`/`hostname:` for
  # other widgets or hosts (controller specs run on "test.host").
  def stub_siteverify(success:, action: TurnstileService::LOGIN_ACTION, hostname: "www.example.com")
    stub_request(:post, TurnstileService::Verify::SITEVERIFY_URL).to_return(
      status: 200,
      body: { "success" => success, "action" => action, "hostname" => hostname }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end
end
