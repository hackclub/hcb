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

      # Signees are redirected to this page right after signing, so let's make sure we have updated data
      @application.contract&.party(:signee)&.sync_with_docuseal
      @application.record_pageview(:show)

      contract_description = if @application.contract.nil?
                               "We'll send you our fiscal sponsorship agreement, which sets the terms and conditions of your usage of HCB."
                             elsif @application.contract.party(:cosigner)&.pending?
                               if @application.contract.party(:signee).signed?
                                 "Your parent or legal guardian (#{@application.cosigner_email}) needs to sign the agreement before we can review your application."
                               else
                                 "You (#{@application.user.email}) and your parent or legal guardian (#{@application.cosigner_email}) need to sign the agreement before we can review your application."
                               end
                             elsif @application.contract.party(:signee).pending?
                               "You (#{@application.user.email}) need to sign the agreement before we can review your application."
                             else
                               "Our team will sign and finalize the contract soon."
                             end

      contract_signed = @application.contract&.party(:signee)&.signed? && !@application.contract&.party(:cosigner)&.pending? && (@application.user.teenager? || @application.contract&.party(:hcb)&.signed?)
      contract_step = {
        label: "Sign agreement",
        shorthand: "Sign",
        name: "Sign the Fiscal Sponsorship Agreement",
        description: contract_description,
        completed: contract_signed
      }

      unless @application.draft?
        @steps = []
        @steps << { label: "Submit application", shorthand: "Submit", completed: true }
        @steps << contract_step if @application.user.teenager?
        @steps << {
          label: "Await review",
          shorthand: "Review",
          name: "Wait for a response from the HCB team",
          description: "Our operations team will review your application and respond within #{@application.response_time}.",
          completed: @application.approved? && (contract_signed || !@application.user.teenager?)
        }
        @steps << contract_step unless @application.user.teenager?
        @steps << {
          label: "Start spending",
          shorthand: "Spend",
          name: "Start spending!",
          description: "You'll have access to your organization to begin raising and spending money.",
          completed: false
        }
      end
    end

    def airtable
      authorize @application

      if @application.airtable_url.present?
        redirect_to @application.airtable_url, allow_other_host: true
      else
        flash[:error] = "This application has not been synced to Airtable yet."
        redirect_to application_path(@application)
      end
    end

    def admin_approve
      authorize @application

      @application.mark_approved!
      flash[:success] = "Application approved."

      if @application.user.teenager?
        party = @application.contract.party :hcb
        redirect_to contract_party_path(party)
      else
        redirect_to submission_application_path(@application)
      end
    end

    def admin_reject
      authorize @application

      @application.mark_rejected!(rejection_message: params[:rejection_message])
      flash[:success] = "Application rejected."
      redirect_back_or_to application_path(@application)
    end

    def admin_activate
      authorize @application

      @application.activate!

      redirect_to event_path(@application.event), flash: { success: "Successfully activated #{@application.event.name}!" }
    end

    def submission
      authorize @application
      @application.record_pageview(:submission)
    end

    def create
      authorize(@application = Event::Application.new(user: current_user))
      @application.save!

      redirect_to project_info_application_path(@application)
    end

    def personal_info
      authorize @application
      @application.record_pageview(:personal_info)
    end

    def project_info
      authorize @application
      @application.record_pageview(:project_info)
    end

    def agreement
      authorize @application
      @application.record_pageview(:agreement)

      @contract = @application.contract || @application.create_contract
      @party = @contract.party :signee
    end

    def review
      authorize @application
      @application.record_pageview(:review)
    end

    def edit
      authorize @application
    end

    def update
      authorize @application

      @application.update!(application_params)

      if user_params.present?
        success = current_user.update(user_params)
        if params[:autosave] != "true" && !success
          render turbo_stream: turbo_stream.replace(:user_errors, partial: "event/applications/error", locals: { user: current_user })
          return
        end
      end

      if params[:autosave] != "true"
        @return_to = url_from(params[:return_to])
        flash[:success] = "Changes saved." if params[:confirm] == "true"

        return redirect_to @return_to if @return_to.present?

        redirect_back_or_to application_path(@application)
      end

      head :no_content
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
      @application = Application.find(params[:id])
    end

    def application_params
      params.require(:event_application).permit(:name, :description, :political_description, :website_url, :address_line1, :address_line2, :address_city, :address_state, :address_postal_code, :address_country, :referrer, :referral_code, :notes, :cosigner_email, :teen_led)
    end

    def user_params
      params.require(:event_application).permit(:full_name, :preferred_name, :phone_number, :birthday)
    end

  end

end
