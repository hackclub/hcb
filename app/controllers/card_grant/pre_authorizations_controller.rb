# frozen_string_literal: true

class CardGrant
  class PreAuthorizationsController < ApplicationController
    before_action :set_card_grant

    def show
      authorize @pre_authorization
    end

    def organizer_approve
      authorize @pre_authorization

      @pre_authorization.mark_approved!

      flash[:success] = "Pre-authorization approved"
      redirect_to card_grant_pre_authorizations_path(@card_grant)
    end

    def organizer_reject
      authorize @pre_authorization

      @pre_authorization.mark_rejected!(current_user)

      flash[:success] = "Pre-authorization rejected, card grant canceled"
      redirect_to card_grant_pre_authorizations_path(@card_grant)
    end

    def organizer_request_resubmit
      authorize @pre_authorization

      # Create a comment on the card grant if feedback was provided
      if params[:feedback].present?
        comment = @card_grant.comments.build(
          content: params[:feedback],
          user: current_user,
          action: :changes_requested
        )
        comment.save!
      end

      @pre_authorization.mark_resubmit_requested!

      flash[:success] = "Pre-authorization sent back for resubmission"
      redirect_to card_grant_pre_authorizations_path(@card_grant)
    end

    def update
      authorize @pre_authorization

      unless @pre_authorization.draft?
        flash[:error] = "You can only update an unsubmitted pre-authorization."
        return redirect_to card_grant_pre_authorizations_path(@card_grant)
      end

      if params[:screenshot].present?
        @pre_authorization.screenshots.attach(params[:screenshot])

        return respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(:screenshot_upload_form, partial: "card_grant/pre_authorizations/screenshot_form", locals: {
                                     success: "#{"Screenshot".pluralize(params[:screenshot].length)} added!",
                                     turbo: true
                                   }),
              turbo_stream.replace(:screenshot_list, partial: "card_grant/pre_authorizations/screenshot_list", locals: {
                                     screenshots: @pre_authorization.screenshots
                                   }),
              turbo_stream.replace(:screenshot_count, partial: "card_grant/pre_authorizations/screenshot_count", locals: {
                                     count: @pre_authorization.screenshots.count,
                                     card_grant: @card_grant,
                                     disabled: !@pre_authorization.draft?
                                   })
            ]
          end

          format.html { redirect_to card_grant_pre_authorizations_path(@card_grant) }
        end
      end

      unless @pre_authorization.update(product_url: pre_authorization_params[:product_url])
        flash[:error] = @pre_authorization.errors.full_messages.to_sentence
        return redirect_to card_grant_pre_authorizations_path(@card_grant)
      end

      if @pre_authorization.product_url.blank? || !@pre_authorization.screenshots.attached?
        flash[:error] = "Please provide a product link and upload a screenshot before submitting."
        return redirect_to card_grant_pre_authorizations_path(@card_grant)
      end

      @pre_authorization.mark_submitted!

      flash[:success] = "Pre-authorization submitted"
      redirect_to card_grant_pre_authorizations_path(@card_grant)
    end

    def clear_screenshots
      authorize @pre_authorization

      @pre_authorization.screenshots.purge

      return respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(:screenshot_list, partial: "card_grant/pre_authorizations/screenshot_list", locals: {
                                   screenshots: @pre_authorization.screenshots
                                 }),
            turbo_stream.replace(:screenshot_count, partial: "card_grant/pre_authorizations/screenshot_count", locals: {
                                   count: @pre_authorization.screenshots.count,
                                   card_grant: @card_grant,
                                   disabled: !@pre_authorization.draft?
                                 })
          ]
        end

        format.html { redirect_to card_grant_pre_authorizations_path(@card_grant) }
      end
    end

    private

    def set_card_grant
      @card_grant = CardGrant.find(params[:card_grant_id])
      @pre_authorization = @card_grant.pre_authorization
      @event = @card_grant.event

      raise ActiveRecord::RecordNotFound if @pre_authorization.nil?
    end

    def pre_authorization_params
      params.require(:card_grant_pre_authorization).permit(:product_url)
    end

  end

end
