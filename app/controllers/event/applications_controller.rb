# frozen_string_literal: true

class Event
  class ApplicationsController < ApplicationController
    before_action :set_application, except: [:new, :create, :index]

    layout "apply"

    def index
      skip_authorization
      @applications = current_user.applications
    end

    def new
      skip_authorization
    end

    def show
      authorize @application
    end

    def create
      @application = Event::Application.create!(user: current_user)
      authorize @application

      redirect_to application_path(@application)
    end

    def personal_info
      authorize @application

    end

    def project_info
      authorize @application

    end

    def update
      authorize @application

      @application.update!(application_params)

      @return_to = url_from(params[:event_application][:return_to])

      return redirect_to @return_to if @return_to.present?
      redirect_back_or_to application_path(@application)
    end

    def submit
      authorize @application
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
      params.require(:event_application).permit(:name, :description, :political, :address_line1, :address_line2, :address_city, :address_state, :address_postal_code, :address_country, :referrer, :referral_code, :notes)
    end

  end

end
