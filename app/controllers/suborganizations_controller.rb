# frozen_string_literal: true

class SuborganizationsController < ApplicationController
  include SetEvent

  before_action :set_event

  def new
    authorize @event, :create_sub_organization?

    @argosy_grant_amount = params[:argosy_grant_amount] if @event.config.subevent_plan == "Event::Plan::Argosy2026"
  end

end
