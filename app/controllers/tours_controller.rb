# frozen_string_literal: true

class ToursController < ApplicationController
  skip_after_action :verify_authorized, only: [:set_step]

  def mark_complete
    @tour = Tour.find(params[:id])
    authorize @tour
    @tour.update(active: false)

    if params[:cancelled] == true
      ahoy.track "Tour canceled", tour_id: @tour.id, tour_options: @tour.tourable.tourable_options, step: @tour.step
    else
      ahoy.track "Tour finished", tour_id: @tour.id, tour_options: @tour.tourable.tourable_options, step: @tour.step
    end

    head :no_content
  end

  def set_step
    step = params[:step].to_i

    return head status: :bad_request if step < 0

    suppress(ActiveRecord::RecordNotFound) do
      @tour = Tour.find(params[:id])
      authorize @tour

      @tour.update(step:)

      ahoy.track "Tour advanced", tour_id: @tour.id, tour_options: @tour.tourable.tourable_options, to_step: step
    end

    head :no_content
  end

end
