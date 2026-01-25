# frozen_string_literal: true

module Referral
  class ProgramsController < ApplicationController
    def create
      @program = Referral::Program.new(name: params[:name], redirect_to: params[:redirect_to].presence || root_url, creator: current_user)

      authorize(@program)

      if @program.save
        flash[:success] = "Referral program created successfully."
      else
        flash[:error] = @program.errors.full_messages.to_sentence
      end

      redirect_to referral_programs_admin_index_path
    end

  end
end
