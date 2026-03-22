# frozen_string_literal: true

class ProcessLoginService
  extend ActiveModel::Naming

  attr_reader(:errors, :login, :user)

  # @param login [Login]
  def initialize(login:)
    @login = login
    @user = login.user
    @errors = ActiveModel::Errors.new(self)
  end

  # @param raw_credential [String]
  # @param challenge [String]
  # @return [Boolean]
  #   Whether the operation succeeded. If `false` check `errors` for details.
  def process_webauthn(raw_credential:, challenge:)
    parsed_credential = begin
      JSON.parse(raw_credential)
    rescue JSON::ParserError
      errors.add(:base, "Invalid security key")
      return false
    end

    webauthn_credential = WebAuthn::Credential.from_get(parsed_credential)

    stored_credential = user.webauthn_credentials.find_by(webauthn_id: webauthn_credential.id)

    unless stored_credential
      errors.add(:base, "Invalid security key")
      return false
    end

    begin
      webauthn_credential.verify(
        challenge,
        public_key: stored_credential.public_key,
        sign_count: stored_credential.sign_count
      )
    rescue WebAuthn::Error
      errors.add(:base, "Failed to verify security key")
      return false
    end

    ActiveRecord::Base.transaction do
      stored_credential.update!(sign_count: webauthn_credential.sign_count)
      login.update!(authenticated_with_webauthn: true)
    end

    true
  end

  # @param code [String]
  # @param sms [Boolean]
  # @return [Boolean]
  #   Whether the operation succeeded. If `false` check `errors` for details.
  def process_login_code(code:, sms:)
    begin
      UserService::ExchangeLoginCodeForUser.new(
        user_id: user.id,
        login_code: code,
        sms:,
      ).run
    rescue Errors::InvalidLoginCode
      errors.add(:base, "Invalid login code")
      return false
    end

    if sms
      login.update!(authenticated_with_sms: true)
    else
      login.update!(authenticated_with_email: true)
    end

    true
  end

  # @param code [String]
  # @return [Boolean]
  #   Whether the operation succeeded. If `false` check `errors` for details.
  def process_totp(code:)
    unless user.totp
      errors.add(:base, "Invalid one-time password")
      return false
    end

    verified = user.totp.verify(code, drift_behind: 15, after: user.totp.last_used_at)

    unless verified
      errors.add(:base, "Invalid one-time password")
      return false
    end

    ActiveRecord::Base.transaction do
      user.totp.update!(last_used_at: DateTime.now)
      login.update!(authenticated_with_totp: true)
    end

    true
  end

  # @param code [String]
  # @return [Boolean]
  #   Whether the operation succeeded. If `false` check `errors` for details.
  def process_backup_code(code:)
    unless user.redeem_backup_code!(code)
      errors.add(:base, "Invalid backup code, please try again.")
      return false
    end

    login.update!(authenticated_with_backup_code: true)

    true
  end

end
