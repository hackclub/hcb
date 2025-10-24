# frozen_string_literal: true

class SuborganizationsController < ApplicationController
  include SetEvent

  before_action :set_event

  def new
    authorize @event, :create_sub_organization?
  end

end
