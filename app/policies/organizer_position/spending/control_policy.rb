class OrganizerPosition::Spending::ControlPolicy < ApplicationPolicy
  def new?
    user.admin? || (
      OrganizerPosition.find_by(user:, event: record.organizer_position.event).manager? &&
      user != record.organizer_position.user
    )
  end

  def destroy?
    user.admin? ||
      OrganizerPosition.find_by(user:, event: record.organizer_position.event).manager?
  end

  private

end
