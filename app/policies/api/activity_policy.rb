# frozen_string_literal: true

module Api
  class ActivityPolicy < ApplicationPolicy
    def show?
      # Authorize against the same event `Api::Entities::Activity` will
      # serialize as `organization` — see `PublicActivity::Activity#event`
      # for the resolution rule. Checking only `event_id` would miss the
      # case where a `recipient_type='Event'` activity serializes the
      # recipient; checking either side would let a public source leak a
      # private destination's balances and users (e.g. disbursements,
      # whose `event_id` is the source and `recipient` is the destination).
      id = record.serialized_event_id
      return false if id.blank?

      Event.indexable.exists?(id:)
    end

  end

end
