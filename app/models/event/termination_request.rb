# frozen_string_literal: true

# == Schema Information
#
# Table name: event_termination_requests
#
#  id              :bigint           not null, primary key
#  closed_at       :datetime
#  reason          :text             not null
#  withdrawn_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  closed_by_id    :bigint
#  event_id        :bigint           not null
#  requested_by_id :bigint           not null
#
# Indexes
#
#  index_event_termination_requests_on_closed_by_id      (closed_by_id)
#  index_event_termination_requests_on_event_id          (event_id)
#  index_event_termination_requests_on_pending_event_id  (event_id) UNIQUE WHERE ((withdrawn_at IS NULL) AND (closed_at IS NULL))
#  index_event_termination_requests_on_requested_by_id   (requested_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (closed_by_id => users.id)
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (requested_by_id => users.id)
#
# A contract signee's request that HCB terminate (close down) their
# organization. Operations processes these by hand, so a request is a ticket:
# it stays pending until a signee withdraws it or an admin closes it.
class Event
  class TerminationRequest < ApplicationRecord
    has_paper_trail

    belongs_to :event
    belongs_to :requested_by, class_name: "User"
    belongs_to :closed_by, class_name: "User", optional: true

    scope :pending, -> { where(withdrawn_at: nil, closed_at: nil) }

    validates :reason, presence: true
    validate :no_other_pending_request, on: :create

    after_create_commit do
      Event::TerminationRequestMailer.with(termination_request: self).notify_operations.deliver_later
      Event::TerminationRequestMailer.with(termination_request: self).confirmation.deliver_later
    end

    def pending?
      withdrawn_at.nil? && closed_at.nil?
    end

    def withdrawn?
      withdrawn_at.present?
    end

    def closed?
      closed_at.present?
    end

    def status
      if withdrawn?
        :withdrawn
      elsif closed?
        :closed
      else
        :pending
      end
    end

    def status_badge_type
      case status
      when :pending then :pending
      when :closed then :success
      else :muted
      end
    end

    def withdraw!
      raise ArgumentError, "only a pending request can be withdrawn" unless pending?

      update!(withdrawn_at: Time.current)
    end

    def close!(closed_by)
      raise ArgumentError, "only a pending request can be closed" unless pending?

      update!(closed_at: Time.current, closed_by:)
    end

    def reopen!
      raise ArgumentError, "only a closed request can be reopened" unless closed?

      update!(closed_at: nil, closed_by: nil)
    end

    private

    def no_other_pending_request
      return unless event&.termination_requests&.pending&.exists?

      errors.add(:base, "This organization already has a pending termination request.")
    end

  end

end
