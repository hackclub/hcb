# frozen_string_literal: true

class DiscordPolicy < ApplicationPolicy
  def unlink_server?
    OrganizerPosition.role_at_least?(user, record, :manager)
  end

  def create_server_link?
    OrganizerPosition.role_at_least?(user, record, :manager)
  end

  def create_link?
    true
  end

  def unlink_server_action?
    OrganizerPosition.role_at_least?(user, record, :manager)
  end

  def link?
    true
  end

  def setup?
    OrganizerPosition.role_at_least?(user, record, :manager)
  end

end
