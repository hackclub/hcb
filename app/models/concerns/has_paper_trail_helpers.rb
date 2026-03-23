# frozen_string_literal: true

module HasPaperTrailHelpers
  extend ActiveSupport::Concern

  def last_user_change_to(...)
    user_id = versions.where_object_changes_to(...).last&.whodunnit

    return nil if user_id.blank? || !user_id.to_s.match?(/\A\d+\z/)

    User.find_by(id: user_id)
  end
end
