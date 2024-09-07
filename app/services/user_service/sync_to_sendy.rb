# frozen_string_literal: true

module UserService
  class SyncToSendy
    def initialize(user_id:, dry_run: true)
      @user = User.includes(:events).find(user_id)
      @dry_run = dry_run
    end

    def run
      recommended_lists.each do |list_id|
        SendyService.subscribe(email: @user.email, list_id:) unless @dry_run
      end

      recommended_lists
    end

    private

    def recommended_lists
      @recommended_lists ||= begin
        lists = []

        return lists unless is_active?

        lists << SendyService::ACTIVE_USERS
        lists << SendyService::HS_USERS if @user&.birthday && @user.birthday > 18.years.ago

        # At the time of writing, the ops team is still categorizing events. To
        # prevent skipping people we'll hold off on this until they confirm
        # they're ready.

        # lists << SendyService::HS_USERS if @user.events.where(category: Event.categories['high school hackathon'])
        # lists << SendyService::HS_HACKATHONS if @user.events.where(category: Event.categories['high school hackathon']).exists?
        # lists << SendyService::ROBOTICS_TEAM if @user.events.where(category: Event.categories['robotics team']).exists?
        # lists << SendyService::ADULT_USERS if @user.event.where(category: Event.categories['hackathon']).exists?
        # lists << SendyService::ADULT_USERS if @user.event.where(category: Event.categories['nonprofit']).exists?

        lists.uniq
      end

      @recommended_lists
    end

    def is_active?
      # onboarded in last 6 months
      return true if @user.created_at > 6.months.ago
      return true if @user.organizer_positions.where("created_at > ?", 6.months.ago)

      # has signed in over the last year
      return true if @user.user_sessions.with_deleted.where("created_at > ?", 1.year.ago).exists?

      # any transaction history over last year
      return true if @user.stripe_cards(&:hcb_codes).any? { |x| x.created_at > 1.year.ago }

      false
    end

  end
end
