# frozen_string_literal: true

module OneTimeJobs
  class AddLastFrozenByIdToStripeCards
    def self.perform
      StripeCard.find_each do |sc|
        sc.update!(last_frozen_by_id: sc.versions.where_object_changes_to(stripe_status: "inactive").last&.whodunnit)
      end
    end

  end
end
