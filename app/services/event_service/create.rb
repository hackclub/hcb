# frozen_string_literal: true

module EventService
  class Create
    def initialize(name:,
                   point_of_contact_id:,
                   cosigner_email: nil,
                   include_onboarding_videos: false,
                   emails: [],
                   is_signee: true,
                   country: [],
                   is_public: true,
                   is_indexable: true,
                   approved: false,
                   plan: Event::Plan::Standard,
                   tags: [],
                   can_front_balance: true,
                   demo_mode: false,
                   risk_level: 0,
                   parent_event: nil,
                   invited_by: nil,
                   scoped_tags: [])
      @name = name
      @emails = emails
      @is_signee = is_signee
      @country = country
      @point_of_contact_id = point_of_contact_id
      @is_public = is_public
      @is_indexable = is_indexable
      @approved = approved || false
      @plan = plan
      @tags = tags
      @can_front_balance = can_front_balance
      @demo_mode = demo_mode
      @risk_level = risk_level
      @parent_event = parent_event
      @invited_by = invited_by
      @cosigner_email = cosigner_email
      @include_onboarding_videos = include_onboarding_videos
      @scoped_tags = scoped_tags || []
    end

    def run
      raise ArgumentError, "organization name is required" unless @name.present?
      raise ArgumentError, "approved must be true or false" unless @approved == true || @approved == false

      ActiveRecord::Base.transaction do
        event = ::Event.create!(attrs)
        @tags
          .filter { |tag| EventTag::Tags::ALL.include?(tag) }
          .each do |tag|
            event.event_tags << ::EventTag.find_or_create_by!(name: tag)
          end


        # Event aasm_state is already approved by default.
        # event.mark_approved! if @approved

        @emails.each do |email|
          invite_service = OrganizerPositionInviteService::Create.new(event:, sender: @invited_by || point_of_contact, user_email: email, is_signee: @is_signee)
          invite_service.run!

          if @is_signee
            invite_service.model.send_contract(cosigner_email: @cosigner_email, include_videos: @include_onboarding_videos)
          end
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
        is_public: @is_public,
        is_indexable: @is_indexable,
        can_front_balance: @can_front_balance,
        point_of_contact_id: @point_of_contact_id,
        demo_mode: @demo_mode,
        financially_frozen: true,
        parent: @parent_event,
        plan: Event::Plan.new(type: @plan),
        event_scoped_tags_events_attributes: @scoped_tags.map { |scoped_tag_id| { event_scoped_tag_id: scoped_tag_id } }
      }.tap do |hash|
        hash[:risk_level] = @risk_level if @risk_level.present?
      end
    end

    def point_of_contact
      @point_of_contact ||= ::User.find(@point_of_contact_id)
    end

  end
end
