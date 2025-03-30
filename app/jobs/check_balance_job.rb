# frozen_string_literal: true

class CheckBalanceJob < ApplicationJob
  queue_as :low
  def perform(event:)
    return if event.id == EventMappingEngine::EventIds::NOEVENT

    Rails.cache.write "event_balance_#{event.id}", event.balance
    Airbrake.notify("#{event.name} has a negative balance: #{ApplicationController.helpers.render_money event.balance}") if event.balance.negative?
  end

end
