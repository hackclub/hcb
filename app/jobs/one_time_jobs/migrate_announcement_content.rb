# frozen_string_literal: true

module OneTimeJobs
  class MigrateAnnouncementContent
    def self.perform
      Announcement.find_each do |announcement|
        json = announcement.content

        unless json.empty?
          begin
            html = ProsemirrorService::Renderer.render_html(json, announcement.event)
            announcement.content = html
            announcement.save!
          rescue
            puts "Failed to render announcement #{announcement.id}"
          end
        end
      end
    end

  end
end
