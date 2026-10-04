# frozen_string_literal: true

class ProcessLoginService
  extend ActiveModel::Naming

  # Email codes are six digits, so without a cap on wrong guesses they can be
  # brute-forced. Attempts are counted per Login and per user; the per-user cap
  # is what bounds an attacker who keeps starting new Logins.
  MAX_EMAIL_CODE_ATTEMPTS_PER_LOGIN = 5
  MAX_EMAIL_CODE_ATTEMPTS_PER_USER = 10
  EMAIL_CODE_ATTEMPTS_WINDOW = 1.hour

  attr_reader(:errors, :login, :user)

  # @param login [Login]
  # @param ip_address [String, nil] recorded on each Login::Attempt
  # @param user_agent [String, nil] recorded on each Login::Attempt
  def initialize(login:, ip_address: nil, user_agent: nil)
    @login = login
    @user = login.user
    @ip_address = ip_address
    @user_agent = user_agent
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
    # Twilio Verify limits attempts on SMS codes itself; email codes are ours.
    return process_email_login_code(code:) unless sms

    begin
      UserService::ExchangeLoginCodeForUser.new(
        user_id: user.id,
        login_code: code,
        sms: true,
      ).run
    rescue Errors::InvalidLoginCode
      errors.add(:base, "Invalid login code")
      return false
    end

    login.update!(authenticated_with_sms: true)

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

  private

  def process_email_login_code(code:)
    # Record the attempt before counting, so concurrent guesses see each other.
    # This must commit on its own, outside any wrapping transaction.
    attempt = login.attempts.create!(factor: :email, ip_address: @ip_address, user_agent: @user_agent)

    user_attempts = Login::Attempt
                    .email
                    .counted
                    .where(created_at: EMAIL_CODE_ATTEMPTS_WINDOW.ago..)
                    .joins(:login)
                    # Attempts can only be made on an active Login, so older
                    # Logins can't have any in the window. Bounding them keeps
                    # this to a few rows of `index_logins_on_user_id_and_created_at`.
                    .where(logins: { user_id: user.id, created_at: (EMAIL_CODE_ATTEMPTS_WINDOW + Login::EXPIRATION).ago.. })
                    .count

    if user_attempts > MAX_EMAIL_CODE_ATTEMPTS_PER_USER
      attempt.blocked!
      errors.add(:base, "Too many incorrect login codes. Please try again later.")
      return false
    end

    if login.attempts.email.counted.count > MAX_EMAIL_CODE_ATTEMPTS_PER_LOGIN
      attempt.blocked!
      errors.add(:base, "Too many incorrect login codes. Please start again and request a new code.")
      return false
    end

    begin
      UserService::ExchangeLoginCodeForUser.new(
        user_id: user.id,
        login_code: code,
        sms: false,
      ).run
    rescue Errors::InvalidLoginCode
      attempt.failed!
      errors.add(:base, "Invalid login code")
      return false
    end

    # A successful sign-in shouldn't eat into the user's budget for the hour.
    attempt.succeeded!
    login.update!(authenticated_with_email: true)

    true
  end

end
