# frozen_string_literal: true

class SudoModeHandler
  # @param controller_instance [ApplicationController]
  def initialize(controller_instance:)
    @controller_instance = controller_instance
  end

  def call
    if params[:_sudo] && params[:_sudo][:method]
      login = Login.incomplete.active.find_by_hashid!(params[:_sudo][:login_id])

      UserService::ExchangeLoginCodeForUser.new(
        user_id: current_user.id,
        login_code: params[:_sudo][:login_code],
        sms: false,
      ).run

      login.update!(authenticated_with_email: true)
      login.update!(current_session:)

      current_session.reload
    else
      login = Login.create!(
        user: current_user,
        initial_login: current_session.initial_login
      )

      # Default preference
      factor_preference = {
        totp: 1,
        webauthn: 2,
        sms: 3,
        email: 4,
      }

      # Put the user's preference first
      user_preference = params.dig(:_sudo, :switch_method).presence || session[:login_preference].presence
      if user_preference.present? && factor_preference.key?(user_preference.to_sym)
        factor_preference[user_preference.to_sym] = 0
      end

      default_factor, *additional_factors = login.available_factors.sort_by { |factor| factor_preference.fetch(factor) }

      # In the case where we know we're going to ask for an SMS or email code,
      # send it ahead of time so the user doesn't have to perform an additional
      # step
      if [:sms, :email].include?(default_factor)
        LoginCodeService::Request.new(
          email: current_user.email,
          sms: default_factor == :sms,
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        ).run
      end

      # Remove extra content from the layout so we only have the
      # reauthentication form on the page.
      controller_instance.instance_variable_set(:@no_app_shell, true)

      controller_instance.render(
        template: "sudo_mode/reauthenticate",
        layout: "application",
        locals: { login:, additional_factors:, default_factor: },
        status: :unprocessable_entity
      )
    end
  end

  private

  attr_reader(:controller_instance)

  delegate(
    :current_user,
    :current_session,
    :params,
    :session,
    :request,
    to: :controller_instance,
    private: true
  )

end
