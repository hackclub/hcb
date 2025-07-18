# frozen_string_literal: true

module OneTimeJobs
  class MigrateAnnouncementBlocks
    def self.perform
      Announcement.find_each do |announcement|
        document = announcement.content

        new_document ProsemirrorService::Renderer.map_nodes document do |node|
          block = case node["type"]
                  when "donationGoal"
                    Announcement::Block.create!(type: "donationGoal", announcement:, parameters: {})
                  when "donationSummary"
                    Announcement::Block.create!(type: "donationSummary", announcement:, parameters: { "start_date" => node["attrs"].&["startDate"] })
                  when "hcbCode"
                    Announcement::Block.create!(type: "hcbCode", announcement:, parameters: { "hcb_code" => node["attrs"].&["code"] })
                  end

          node["attrs"] = { "id" => block.id }
        end

        announcement.content = document
        announcement.save!
      end
    end

  end
end
