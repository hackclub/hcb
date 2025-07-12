# frozen_string_literal: true

class CheckBalanceJob < ApplicationJob
  queue_as :low
  def perform(event:)
    return if event.slug == EventMappingEngine::EventSlugs::NOEVENT

    Airbrake.notify("#{event.name} has a negative balance: #{ApplicationController.helpers.render_money event.balance}") if event.balance.negative?
  end

end
