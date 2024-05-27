class OrganizerPosition::Spending::AllowancePolicy < ApplicationPolicy
  def index?
    # `record` in this method is an OrganizerPosition
    user.admin? || record.manager? || user == record.user
  end

  def new?
    true
  end

  def create?
    user.admin? ||
      OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

end
