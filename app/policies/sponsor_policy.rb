# frozen_string_literal: true

class SponsorPolicy < ApplicationPolicy
  # Sponsors are not published by v3, so there is no transparency branch: a
  # sponsor is visible only to people who can read its organization.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.auditor?
      return scope.none if user.nil?

      scope.where(event_id: user.readable_event_ids.to_a)
    end

  end

  def index?
    auditor_or_reader?
  end

  # sponsors can never be seen in transparency mode
  def show?
    auditor_or_reader?
  end

  def new?
    admin_or_member?
  end

  def create?
    admin_or_member?
  end

  def edit?
    admin_or_member?
  end

  def update?
    admin_or_member?
  end

  def destroy?
    admin_or_member?
  end

  def permitted_attributes
    attrs = [
      :name,
      :contact_email,
      :address_line1,
      :address_line2,
      :address_city,
      :address_state,
      :address_postal_code,
      :address_country,
      :id
    ]

    attrs << :event_id if user&.admin?

    attrs
  end


  # See ApplicationPolicy#visible_attributes. Sponsors have no v3 entity, so
  # there is no public tier — a transparent organization does not publish who
  # invoices it. SponsorPolicy#show? already says as much.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []
      attrs += %i[name slug event_id] if show?
      attrs += %i[contact_email address_line1 address_line2 address_city address_state
                  address_postal_code address_country] if show?
      attrs << :stripe_customer_id if user&.auditor?
      attrs
    end
  end


  # Strong parameters for writes. Already the shape v4 uses at
  # `sponsors_controller.rb:69` — this is Pundit's `permitted_attributes` doing
  # the job it was designed for, which is why the read list has its own name.
  def permitted_attributes
    %i[name contact_email address_line1 address_line2 address_city
       address_state address_postal_code address_country]
  end

  private

  def auditor_or_reader?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record&.event, :reader)
  end

  def admin_or_member?
    user&.admin? || OrganizerPosition.role_at_least?(user, record&.event, :member)
  end

end
