# frozen_string_literal: true

class NotifyEventsWithNegativeBalanceJob
  # This job uses Sidekiq directly so it can leverage its support for iteration
  # (https://github.com/sidekiq/sidekiq/wiki/Iteration), as the ActiveJob
  # equivalent has yet to be released.
  # (https://edgeapi.rubyonrails.org/classes/ActiveJob/Continuable.html)
  include Sidekiq::IterableJob

  sidekiq_options(queue: :low, retry: false)

  def build_enumerator(cursor:)
    active_record_records_enumerator(Event.all, cursor:)
  end

  def each_iteration(event)
    return if event.plan.is_a?(Event::Plan::Internal)

    event_balance = event.balance
    return unless event_balance.negative?

    EventMailer
      .with(event:, balance: event_balance)
      .negative_balance
      .deliver_later
  end

end
