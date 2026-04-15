# frozen_string_literal: true

module Users
  class FirstController < ApplicationController
    include UsersHelper

    skip_after_action :verify_authorized
    skip_before_action :signed_in_user

    TBA_API_KEY = Credentials.fetch(:THE_BLUE_ALLIANCE, :API_KEY)
    TBA_BASE_URL = "https://www.thebluealliance.com/api/v3"

    def index
    end

    def team
      league = params[:league].to_s.downcase
      team_number = params[:team_number].to_s

      conn = Faraday.new(url: TBA_BASE_URL) do |f|
        f.headers["X-TBA-Auth-Key"] = TBA_API_KEY
      end

      team_key = "frc#{team_number}"
      team_response = conn.get("team/#{team_key}")

      unless team_response.success?
        return render json: { error: "Team not found" }, status: :not_found
      end

      team_data = JSON.parse(team_response.body)

      avatar = nil
      media_response = conn.get("team/#{team_key}/media/#{Date.today.year}")
      if media_response.success?
        media = JSON.parse(media_response.body)
        avatar_media = media.find { |m| m["type"] == "avatar" }
        if avatar_media
          base64 = avatar_media.dig("details", "base64Image")
          avatar = base64.present? ? "data:image/png;base64,#{base64}" : avatar_media["direct_url"].presence
        end
      end

      render json: {
        league: league,
        team_number: team_number,
        team_name: team_data["nickname"],
        avatar: avatar
      }
    end

    def sign_out
      cookies.delete("user_token")
      redirect_to auth_users_path
    end

    def new
      @referral_link_slug = Referral::Link.find_by(slug: params[:referral])&.slug if params[:referral].present?
      @user = User.new(affiliations: [Event::Affiliation.new])
    end

    def create
      @user = User.new(user_params)

      if User.where(email: @user.email).exists?
        flash[:error] = "That email is already taken"
        redirect_back_or_to welcome_first_index_path
      end

      @user.creation_method = :first_robotics_form
      @user.save!

      cookies.signed["user_token"] = @user.signed_id(expires_in: 2.weeks, purpose: :unverified_persistence)

      redirect_to first_index_path
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message

      redirect_back_or_to welcome_first_index_path
    end

    private

    def user_params
      params.require(:user).permit(:email, :full_name, affiliations_attributes: [:league, :team_number, :name, :team_name, :role])
    end

  end
end
