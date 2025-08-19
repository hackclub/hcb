# frozen_string_literal: true

class CheckBalanceJob < ApplicationJob
  queue_as :low

  # `sidekiq_options` is only available in the production environment where we
  # use the `Sidekiq` adapter for `ActiveJob`.
  if respond_to?(:sidekiq_options)
    sidekiq_options(retry: false)
  end

  def perform(event:)
    return if event.id == EventMappingEngine::EventIds::NOEVENT

    Rails.error.unexpected "#{event.name} has a negative balance: #{ApplicationController.helpers.render_money event.balance}" if event.balance.negative?
  end

end
