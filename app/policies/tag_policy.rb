# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  # Tags follow their organization: v3 publishes them on a transparent
  # organization's transactions.
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(event: Event.visible_to(user))
    end

  end

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

  # See ApplicationPolicy#visible_attributes. v3's `tag` entity publishes the
  # label; colour and emoji carry no more information than the label does.
  def visible_attributes
    @visible_attributes ||= transparent_or_reader? ? %i[label color emoji] : []
  end


  # Strong parameters for writes. Distinct from #visible_attributes: the fields
  # a caller may *send* and the fields it may *see* are different questions, and
  # conflating them is why the read list is not called `permitted_attributes`.
  def permitted_attributes
    %i[label color emoji]
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

end
