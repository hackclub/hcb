# frozen_string_literal: true

class Contract
  class PartiesController < ApplicationController
    before_action :set_party
    skip_before_action :signed_in_user, only: [:show, :completed]

    def show
      begin
        authorize @party
      rescue Pundit::NotAuthorizedError
        if signed_in?
          raise
        else
          skip_authorization
          return redirect_to auth_users_path(return_to: contract_party_path(@party)), flash: { info: "To continue, please sign in with the email that you received the invitation with." }
        end
      end

      # The DocuSeal webhook may not have landed yet (or, in dev, may never
      # land at all — it can't reach localhost) by the time this page loads,
      # so reconcile directly with DocuSeal rather than relying on it alone.
      @party.sync_with_docuseal if @party.pending? && @contract.sent_with_docuseal?

      if @party.signed? && !(@contract.contractable.is_a?(Event::Application) && @party.hcb?)
        redirect_to completed_contract_party_path(@party)
        return
      elsif @contract.voided?
        @contracts = signed_in? ? current_user.contracts.sent.select { |contract| contract.party(:signee).present? } : []
        render "contract/parties/voided"
        return
      elsif @contract.pending?
        flash[:error] = "This contract has not been sent yet. Try again later."
        Rails.error.unexpected("Contract not sent, but user is trying to sign it. Party ID: #{@party.id}")
        redirect_to root_path
        return
      end
    end

    def resend
      authorize @party
      @party.notify

      flash[:success] = "Contract successfully resent to #{@party.email}."
      redirect_back(fallback_location: @contract.redirect_path)
    end

    def completed
      authorize @party
      # This is where DocuSeal's embedded form redirects to right after the
      # signature completes, so this is the most important place to catch up
      # — the webhook is often still in flight when the browser lands here.
      @party.sync_with_docuseal if @party.pending? && @contract.sent_with_docuseal?

      if (@party.signee? && @contract.signed?) || @party.contractor?
        case @contract.contractable
        when Event::Application
          redirect_to application_path(@contract.contractable)
        when OrganizerPositionInvite
          redirect_to organizer_position_invite_path(@contract.contractable)
        when Payroll::Position
          redirect_to onboarding_payroll_position_path(@contract.contractable)
        end

        return
      end

      confetti!
    end

    private

    def set_party
      @party = Contract::Party.find_by_hashid!(params[:id])
      @contract = @party.contract
    end

  end

end
