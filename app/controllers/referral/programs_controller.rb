# frozen_string_literal: true

module Referral
  class ProgramsController < ApplicationController
    before_action :set_program, only: :show

    def show
      if @program
        authorize(@program)

        Rails.error.handle do
          Referral::Attribution.create!(user: current_user, program: @program)
        end
      else
        skip_authorization
      end

      redirect_to params[:return_to] || root_path
    end

    private

    def set_program
      @program = Referral::Program.find_by_hashid(params[:id])
    end

  end
end
