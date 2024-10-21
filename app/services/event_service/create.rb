# frozen_string_literal: true

module EventService
  class Create
    def initialize(name:, point_of_contact_id:, emails: [], is_signee: true, country: [], category: [], is_public: true, is_indexable: true, approved: false, plan_type: Event::Plan::Standard, organized_by_hack_clubbers: false, organized_by_teenagers: false, omit_stats: false, can_front_balance: true, demo_mode: false)
      @name = name
      @emails = emails
      @is_signee = is_signee
      @country = country
      @category = category
      @point_of_contact_id = point_of_contact_id
      @is_public = is_public
      @is_indexable = is_indexable
      @approved = approved || false
      @plan_type = plan_type
      @organized_by_hack_clubbers = organized_by_hack_clubbers
      @organized_by_teenagers = organized_by_teenagers
      @omit_stats = omit_stats
      @can_front_balance = can_front_balance
      @demo_mode = demo_mode
    end

    def run
      raise ArgumentError, "name required" unless @name.present?
      raise ArgumentError, "approved must be true or false" unless @approved == true || @approved == false

      ActiveRecord::Base.transaction do
        event = ::Event.create!(attrs)
        event.event_tags << ::EventTag.find_or_create_by!(name: EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS) if @organized_by_hack_clubbers
        event.event_tags << ::EventTag.find_or_create_by!(name: EventTag::Tags::ORGANIZED_BY_TEENAGERS) if @organized_by_teenagers

        # Event aasm_state is already approved by default.
        # event.mark_approved! if @approved

        @emails.each do |email|
          OrganizerPositionInviteService::Create.new(event:, sender: point_of_contact, user_email: email, is_signee: @is_signee).run!
        end

        event
      end
    end

    private

    def attrs
      {
        name: @name,
        address: "N/A",
        country: @country,
        category: @category,
        omit_stats: @omit_stats,
        is_public: @is_public,
        is_indexable: @is_indexable,
        can_front_balance: @can_front_balance,
        expected_budget: 100.0,
        point_of_contact_id: @point_of_contact_id,
        organization_identifier:,
        demo_mode: @demo_mode,
        plan: Event::Plan.new(plan_type: @plan_type)
      }
    end

    def point_of_contact
      @point_of_contact ||= ::User.find(@point_of_contact_id)
    end

    def organization_identifier
      @organization_identifier ||= "hcb_#{SecureRandom.hex}"
    end

  end
end
