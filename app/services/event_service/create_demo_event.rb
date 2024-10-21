# frozen_string_literal: true

module EventService
  class CreateDemoEvent
    # include ::UserService::CanOpenDemoMode

    def initialize(email:, name:, country:, category: nil, point_of_contact_id: nil, is_public: true, postal_code: nil)
      @email = email
      @point_of_contact = point_of_contact_id ? User.find(point_of_contact_id) : User.find_by_email("bank@hackclub.com")
      @event = ::Event.new(
        name:,
        country:,
        category:,
        postal_code:,
        point_of_contact_id: @point_of_contact.id,
        is_public:,
        organization_identifier:,
        omit_stats: false,
        can_front_balance: true,
        demo_mode: true
      )
    end

    def run
      ActiveRecord::Base.transaction do
        @event.demo_mode_limit_email = @email

        @event.save!

        OrganizerPositionInviteService::Create.new(event: @event, sender: @point_of_contact, user_email: @email, initial: true).run!

        @event
      end
    end

    private

    def organization_identifier
      @organization_identifier ||= "bank_#{SecureRandom.hex}"
    end

  end
end
