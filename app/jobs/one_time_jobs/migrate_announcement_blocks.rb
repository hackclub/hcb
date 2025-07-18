# frozen_string_literal: true

module OneTimeJobs
  class MigrateAnnouncementBlocks
    def self.perform
      Announcement.find_each do |announcement|
        document = announcement.content

        new_document = ProsemirrorService::Renderer.map_nodes document do |node|
          block = case node["type"]
                  when "donationGoal"
                    Announcement::Block.create!(type: "Announcement::Block::DonationGoal", announcement:, parameters: {})
                  when "donationSummary"
                    Announcement::Block.create!(type: "Announcement::Block::DonationSummary", announcement:, parameters: { "start_date" => node["attrs"].present? ? node["attrs"]["startDate"] : nil })
                  when "hcbCode"
                    Announcement::Block.create!(type: "Announcement::Block::HcbCode", announcement:, parameters: { "hcb_code" => node["attrs"].present? ? node["attrs"]["code"] : nil })
                  end

          if block.present?
            node["attrs"] = { "id" => block.id }
          end
        end

        announcement.content = new_document
        announcement.save!
      end
    end

  end
end
