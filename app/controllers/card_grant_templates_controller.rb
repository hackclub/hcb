# frozen_string_literal: true

class CardGrantTemplatesController < ApplicationController
  include SetEvent
  include CardGrantFormParams

  before_action :set_event
  before_action :set_card_grant_template, only: [:update, :destroy]

  def create
    @card_grant_template = @event.card_grant_templates.build(name: template_name_param, created_by: current_user)

    authorize @card_grant_template

    save_from_form("Saved template “#{@card_grant_template.name}”.")
  end

  def update
    authorize @card_grant_template

    save_from_form("Updated template “#{@card_grant_template.name}”.")
  end

  def destroy
    authorize @card_grant_template

    @card_grant_template.destroy!

    flash[:success] = "Deleted template “#{@card_grant_template.name}”."
    redirect_to new_event_card_grant_path(@event)
  end

  private

  def template_name_param
    params[:template_name] if params[:template_name].is_a?(String)
  end

  def set_card_grant_template
    @card_grant_template = @event.card_grant_templates.find_by_hashid!(params[:id])
  end

  def save_from_form(success_message)
    attributes = card_grant_form_params.except(:email)
    attributes[:amount_cents] = nil if params.dig(:card_grant, :amount_cents).blank?

    @card_grant = @event.card_grants.build(attributes)
    @card_grant_template.assign_from(@card_grant)

    if save_card_grant_template
      flash[:success] = success_message
      redirect_to new_event_card_grant_path(@event, template_id: @card_grant_template.hashid)
    else
      # Re-render the form so nothing that was typed in gets lost.
      @card_grant.email = params.dig(:card_grant, :email)
      @template = @card_grant_template.persisted? ? @card_grant_template : @event.card_grant_templates.find_by_hashid(params[:template_id].to_s)
      flash.now[:error] = @card_grant_template.errors.full_messages.to_sentence
      render "card_grants/new", status: :unprocessable_content
    end
  end

  def save_card_grant_template
    @card_grant_template.save
  rescue ActiveRecord::RecordNotUnique
    # Lost a race with another request saving a template with the same name.
    @card_grant_template.errors.add(:name, :taken)
    false
  end

end
