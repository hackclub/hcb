# frozen_string_literal: true

class PublicActivity::Activity
  scope :for_user, ->(user) {
    where(recipient_type: "User", recipient_id: user.id)
      .or(where(event_id: user.events.pluck(:id)))
      .or(where(recipient_type: "Event", recipient_id: user.events.pluck(:id)))
  }

  scope :for_event, ->(event) {
    where(event_id: event.id)
      .or(where(recipient_type: "Event", recipient_id: event.id))
  }

  include Turbo::Broadcastable

  after_create_commit -> {
    # this code has been tested
    # but because this will run so often
    # i don't want it to break other features
    # as it's non-critical, hence this.
    # - @sampoder
    begin
      streams = []

      if event_id
        Event.find(event_id).users.each do |user|
          streams << [user, "activities"]
          streams << [user, Event.find(event_id), "activities"]
        end
      end

      if recipient.is_a?(User)
        streams << [recipient, "activities"]
      end

      if recipient.is_a?(Event)
        recipient.users.each do |user|
          streams << [user, "activities"]
          streams << [user, recipient, "activities"]
        end
      end

      User.admin.each do |user|
        streams << [user, "activities"]
      end

      streams.uniq.each do |stream|
        broadcast_action_later_to(
          stream,
          action: :prepend,
          target: "activities-1",
          partial: "public_activity/activity",
          locals: { activity: self, current_user: stream.first }
        )
      end
    rescue => e
      Airbrake.notify(e)
    end

  }

  validate do
    owner.nil? || owner_type == User.name
  end

  def trackable_is_deletable?
    trackable_type.constantize.in?([Reimbursement::Report, WebauthnCredential, Comment])
  end

end
