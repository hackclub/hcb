# frozen_string_literal: true

module HasPaperTrailHelpers
  extend ActiveSupport::Concern

  def last_user_change_to(...)
    user_id = versions.where_object_changes_to(...).last&.whodunnit

    user_id && User.find(user_id)
  end
end
