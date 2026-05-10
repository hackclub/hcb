# frozen_string_literal: true

# Shared context for specs that exercise route constraints (or anything else)
# that reads `request.cookie_jar.encrypted[:session_token]`. Define a
# `:session_token` `let` in the including spec; it will be returned from the
# encrypted cookie jar.
RSpec.shared_context "with stubbed session_token cookie" do
  # String-form `instance_double` so verification doesn't trip when the lazy-
  # loaded `ActionDispatch::Cookies::CookieJar` constant isn't yet autoloaded
  # (e.g. when running a single spec in isolation).
  let(:request) { instance_double("ActionDispatch::Request", cookie_jar:) }
  let(:cookie_jar) { instance_double("ActionDispatch::Cookies::CookieJar", encrypted: encrypted_jar) }
  let(:encrypted_jar) { { session_token: } }
end
