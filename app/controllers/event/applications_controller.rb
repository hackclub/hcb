# frozen_string_literal: true

class Event
  class ApplicationsController < ApplicationController
    before_action :set_application, except: [:new, :create]

    layout "apply"

    def new
      skip_authorization
    end

    def show
      authorize @application
    end

    def create
      @application = Event::Application.create!(user: current_user)
      authorize @application

      redirect_to edit_application_path(@application)
    end

    def update
      authorize @application

      @application.update!(application_params)

      new_step = params[:step].to_i + 1

      redirect_to application_step_path(@application, step: new_step)
    end

    def step
      authorize @application

      step_number = params[:step].to_i || 0
      step = Event::Application::APPLICATION_STEPS[step_number]

      render "event/applications/steps/#{step}"
    end

    private

    def set_application
      @application = Application.find(params[:application_id] || params[:id])
    end

    def application_params
      params.permit(:name, :description, :political, :address_line1, :address_line2, :address_city, :address_state, :address_postal_code, :address_country, :referrer, :referral_code, :notes)
    end

  end

end
