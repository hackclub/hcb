# frozen_string_literal: true

module SessionSupport
  # Implements just enough of the logic in `SessionHelper#sign_in` to make it
  # easier to make authenticated requests in controller tests.
  #
  # @param user [User]
  # @return [UserSession]
  def sign_in(user)
    expiration_at = user.session_duration_seconds.seconds.from_now

    required_factor_count = user.use_two_factor_authentication ? 2 : 1
    login = build(:login, user:)
    factors = login.available_factors.take(required_factor_count)

    if factors.size < required_factor_count
      raise(ArgumentError, "user #{user.id} has 2fa enabled despite having only a single available factor")
    end

    login.assign_attributes(factors.to_h { |factor| [:"authenticated_with_#{factor}", true] })
    login.save!

    user_session = create(:user_session, user:, expiration_at:)
    login.update!(user_session:)

    cookies.encrypted[:session_token] = {
      value: user_session.session_token,
      expires: expiration_at,
      httponly: true,
      secure: true,
    }

    user_session
  end

  # Mimics the logic in `SessionHelper#current_session` so the active
  # `UserSession` record can easily be retrieved in tests.
  #
  # @return [UserSession]
  # @raise [ActiveRecord::RecordNotFound]
  def current_session!
    session_token = cookies.encrypted[:session_token]
    UserSession.find_by!(session_token:)
  end
end
