# frozen_string_literal: true

module OneTimeJobs
  class BackfillAnnouncementAasm
    def self.perform
      Announcement.find_each do |announcement|
        if announcement.published_at.present?
          announcement.aasm_state = :published
        else
          announcement.aasm_state = :draft
        end

        announcement.save!
      end
    end

  end
end
