# frozen_string_literal: true

module OneTimeJobs
  class MigrateBlockTypes
    def self.perform
      Announcement.find_each do |announcement|
        new_content = ProsemirrorService::Renderer.map_nodes announcement.content do |node|
          new_type = case node["type"]
                     when "donationGoal"
                       "Announcement::Block::DonationGoal"
                     when "donationSummary"
                       "Announcement::Block::DonationSummary"
                     when "hcbCode"
                       "Announcement::Block::HcbCode"
                     else
                       node["type"]
                     end

          node["type"] = new_type
        end

        announcement.content = new_content

        announcement.save!
      end

    end

  end
end
