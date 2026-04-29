# frozen_string_literal: true

module Users
  class FirstController < ApplicationController
    include UsersHelper

    skip_after_action :verify_authorized
    skip_before_action :signed_in_user
    invisible_captcha only: [:create], honeypot: :remember_me

    def index
      return redirect_to welcome_first_index_path unless signed_in?(allow_unverified: true)

      @macbook_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-macbook")
      @printer_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-printer")
      @airpods_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-airpods")
    end

    def team
      if ["ftc", "fll"].include?(params[:league])
        return render json: { error: "Team prefill is unsupported for #{params[:league]}" }, status: :not_found
      end

      result = Event::Affiliation.tba_lookup(params[:league], params[:team_number])

      if result.nil?
        return render json: { error: "Team not found" }, status: :not_found
      end

      render json: result
    end

    def sign_out
      helpers.sign_out

      redirect_to auth_users_path
    end

    def new
      return redirect_to first_index_path if signed_in?(allow_unverified: true)

      @referral_link_slug = Referral::Link.find_by(slug: params[:referral])&.slug if params[:referral].present?
      @user = User.new(affiliations: [Event::Affiliation.new])
    end

    def verify_email
      return redirect_to welcome_first_index_path unless current_user(allow_unverified: true)&.unverified?

      @login = Login.create!(state: { purpose: "first", return_to: first_index_path }, user: current_user(allow_unverified: true))

      cookies.signed["browser_token_#{@login.hashid}"] = { value: @login.browser_token, expires: Login::EXPIRATION.from_now }

      redirect_to choose_login_preference_login_path(@login)
    end

    def create
      program = nil
      program = "first-worlds-2026-macbook" if ["student_leader", "student_member"].include?(user_params.dig(:affiliations_attributes, "0", "role"))

      unless User.where(email: user_params[:email]).exists?
        @user = User.new(user_params)
        @user.creation_method = :first_robotics_form
        @user.save!

        Raffle.find_or_create_by!(user: @user, program:) if program.present?

        create_session(user: @user, verified: false)

        redirect_to first_index_path and return
      end

      @user = User.find_by!(email: user_params[:email])
      @login = Login.create!(state: { purpose: "first", return_to: first_index_path, user_params:, raffle: program }, user: @user)

      cookies.signed["browser_token_#{@login.hashid}"] = { value: @login.browser_token, expires: Login::EXPIRATION.from_now }

      redirect_to choose_login_preference_login_path(@login)
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message

      render :new, status: :unprocessable_entity
    end

    private

    def user_params
      params.require(:user).permit(:email, :full_name, affiliations_attributes: [:league, :team_number, :name, :team_name, :role])
    end

  end
end
