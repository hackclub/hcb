# frozen_string_literal: true

module OneTimeJobs
  class AddLastFrozenByToStripeCards
    def self.perform
      StripeCard.find_each do |sc|
        last_frozen_by_id = sc.versions.where_object_changes_to(stripe_status: "inactive").last&.whodunnit || User.system_user.id
        sc.update!(last_frozen_by_id:)
      end
    end

  end
end
