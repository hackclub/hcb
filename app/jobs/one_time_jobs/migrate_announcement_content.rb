# frozen_string_literal: true

module OneTimeJobs
  class MigrateAnnouncementContent
    def self.perform
      Announcement.find_each do |announcement|
        json = announcement.content

        unless json.empty?
          begin
            html = ProsemirrorService::Renderer.render_html(json, announcement.event)
            announcement.rendered_html = html

            email_html = ProsemirrorService::Renderer.render_html(json, announcement.event, is_email: true)
            announcement.rendered_email_html = email_html

            announcement.save!
          rescue => e
            puts e
            puts "Failed to render announcement #{announcement.id}"
          end
        end
      end
    end

  end
end
