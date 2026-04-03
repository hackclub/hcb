# frozen_string_literal: true

module Users
  class FirstController < ApplicationController
    include UsersHelper

    skip_after_action :verify_authorized
    skip_before_action :signed_in_user
    
    def index
    end

    def new
      @referral_link_slug = Referral::Link.find_by(slug: params[:referral])&.slug if params[:referral].present?
      @user = User.new(affiliations: [Event::Affiliation.new])
    end

    def create
      byebug
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
      params.require(:user).permit(:email, :full_name, affiliations_attributes: [:league, :team_number, :name])
    end
  end
end
