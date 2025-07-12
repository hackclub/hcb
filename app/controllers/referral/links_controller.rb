# frozen_string_literal: true

module Referral
  class LinksController < ApplicationController
    before_action :set_link, only: :show

    def show
      if @link
        authorize(@link)

        Rails.error.handle do
          Referral::Attribution.create!(user: current_user, program: @link.program)
        end
      else
        skip_authorization
      end

      redirect_to params[:return_to] || root_path
    end

    private

    def set_link
      @program = Referral::Link.find_by_hashid(params[:id])
    end

  end
end
