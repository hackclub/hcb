# frozen_string_literal: true

class Event
  class ApplicationsController < ApplicationController
    before_action :set_application, except: [:apply, :new, :create, :index]
    skip_before_action :signed_in_user, only: [:new, :apply]
    skip_before_action :redirect_to_onboarding

    layout "apply"

    def index
      skip_authorization
      @applications = current_user.applications
    end

    def apply
      skip_authorization

      if signed_in? && current_user.applications.draft.one?
        redirect_to application_path(current_user.applications.draft.first)
      elsif signed_in? && current_user.applications.any?
        redirect_to applications_path
      else
        redirect_to new_application_path
      end
    end

    def new
      skip_authorization
    end

    def show
      authorize @application
    end

    def create
      authorize(@application = Event::Application.new(user: current_user))
      @application.save!

      redirect_to project_info_application_path(@application)
    end

    def personal_info
      authorize @application

    end

    def project_info
      authorize @application
    end

    def review
      authorize @application
    end

    def update
      authorize @application

      ap application_params
      ap user_params

      @application.update!(application_params)

      @return_to = url_from(params[:return_to])

      if user_params.present?
        current_user.update!(user_params)
      end

      return redirect_to @return_to if @return_to.present?

      redirect_back_or_to application_path(@application)
    end

    def submit
      authorize @application
      @application.mark_submitted!
      confetti!
      redirect_to application_path(@application)
    end

    private

    def set_application
      @application = Application.find(params[:application_id] || params[:id])
    end

    def application_params
      params.require(:event_application).permit(:name, :description, :political_description, :website_url, :address_line1, :address_line2, :address_city, :address_state, :address_postal_code, :address_country, :referrer, :referral_code, :notes, :cosigner_email)
    end

    def user_params
      params.require(:event_application).permit(:full_name, :preferred_name, :phone_number, :birthday)
    end

  end

end
