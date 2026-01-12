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

      unless @application.draft?
        @steps = [
          { title: "Wait for a response from the HCB team", description: "Our operations team will review your application and respond within 24 hours." },
          { title: "Start spending!", description: "You'll have access to your organization to begin raising and spending money." }
        ]

        if @application.cosigner_email.present?
          @steps.unshift({ title: "Have your parent sign the Fiscal Sponsorship Agreement", description: "Your parent or legal guardian (#{@application.cosigner_email}) needs to cosign the agreement you signed before we can review your application." })
        end
      end
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

    def agreement
      authorize @application

      @contract = @application.contract || @application.create_contract
      @party = @contract.party :signee
    end

    def review
      authorize @application

      @contract_signed = @application.signee_signed?
    end

    def update
      authorize @application

      ap application_params
      ap user_params

      @application.update!(application_params)

      if @application&.contract&.party(:signee)&.signed?
        @application.contract.mark_voided!
      end

      @return_to = url_from(params[:return_to])

      if user_params.present?
        current_user.update!(user_params)
      end

      return redirect_to @return_to if @return_to.present?

      redirect_back_or_to application_path(@application)
    end

    def submit
      authorize @application

      if @application.ready_to_submit?
        @application.mark_submitted!
        confetti!
        redirect_to application_path(@application)
      else
        flash[:error] = "This application is not ready to submit"
        redirect_to review_application_path(@application)
      end
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
