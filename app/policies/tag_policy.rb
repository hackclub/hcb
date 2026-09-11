# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  def show?
    reader? || auditor?
  end

  def create?
    OrganizerPosition.role_at_least?(user, record, :member)
  end

  def update?
    member?
  end

  def destroy?
    member?
  end

  def toggle_tag?
    member?
  end

  private

  def auditor?
    user&.auditor?
  end

  def reader?
    OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def member?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end


  # See ApplicationPolicy#visible_attributes. v3's `tag` entity publishes the
  # label; colour and emoji carry no more information than the label does.
  def visible_attributes
    @visible_attributes ||= transparent_or_reader? ? %i[label color emoji] : []
  end

end
