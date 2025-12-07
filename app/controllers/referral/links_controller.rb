# frozen_string_literal: true

module Referral
  class LinksController < ApplicationController
    before_action :set_link, only: :show
    skip_before_action :signed_in_user, only: :show

    def show
      unless signed_in?
        skip_authorization
        return redirect_to auth_users_path(referral: @link)
      end

      if @link
        authorize(@link)

        Rails.error.handle do
          Referral::Attribution.create!(user: current_user, program: @link.program, link: @link)
        end

        redirect_to @link.program.redirect_to.presence || root_path, allow_other_host: true
      else
        skip_authorization

        redirect_to params[:return_to] || root_path
      end
    end

    private

    def set_link
      @link = Referral::Link.find_by(slug: params[:id]).presence || Referral::Link.find_by_hashid(params[:id])
    end

  end
end
