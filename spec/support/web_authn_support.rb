# frozen_string_literal: true

require "webauthn/fake_client"

module WebAuthnSupport
  def self.included(base)
    unless base < RSpec::Core::ExampleGroup
      raise ArgumentError, "#{self.name} can only be included in an RSpec example group"
    end

    base.class_eval do
      let(:webauthn_client) { WebAuthn::FakeClient.new(WebAuthn.configuration.origin) }
    end
  end

  # Generates a WebAuthn credential for the given user using `webauthn_client`
  # and stores it in the database.
  #
  # @param user [User]
  # @return [WebauthnCredential]
  def create_webauthn_credential(user:)
    if user.webauthn_id.blank?
      user.update!(webauthn_id: WebAuthn.generate_user_id)
    end

    # Simulate `WebauthnCredentialsController#register_options`
    create_options = WebAuthn::Credential.options_for_create(
      user: {
        id: user.webauthn_id,
        name: user.email,
        display_name: user.name
      },
      authenticator_selection: {
        authenticator_attachment: "platform",
        user_verification: "discouraged"
      }
    )

    # Create a new credential (this logic is performed in the browser)
    # See `app/javascript/controllers/webauthn_register_controller.js`
    create_payload = webauthn_client.create(challenge: create_options.challenge)

    # Simulate `WebauthnCredentialsController#create`
    credential = WebAuthn::Credential.from_create(create_payload)
    expect(credential.verify(create_options.challenge)).to eq(true)

    user.webauthn_credentials.create!(
      webauthn_id: credential.id,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      name: "Test Credential",
      authenticator_type: "platform",
    )
  end

  # Simulates `UsersController#webauthn_options` to obtain a challenge that can be
  # used with `get_webauthn_credential`.
  #
  # @param user [User]
  # @return [String]
  def generate_webauthn_challenge(user:)
    get_options = WebAuthn::Credential.options_for_get(
      allow: user.webauthn_credentials.pluck(:webauthn_id),
      user_verification: "discouraged"
    )

    get_options.challenge
  end

  # Retrieve a credential using the given challenge (see `generate_challenge`)
  # which can be used to log in
  #
  # @param challenge [String]
  # @return [Hash]
  def get_webauthn_credential(challenge:)
    # This logic is performed in the browser
    # See `app/javascript/controllers/webauthn_auth_controller.js`
    webauthn_client.get(challenge:)
  end
end
