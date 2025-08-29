# frozen_string_literal: true

xml.instruct! :xml, version: "1.0"

xml.feed xmlns: "http://www.w3.org/2005/Atom" do
  xml.title "#{@event.name} – Announcements"
  xml.updated @updated_at.present? ? @updated_at.xmlschema : @event.created_at.xmlschema
  xml.link rel: "self", href: event_feed_url(@event)
  xml.link rel: "alternate", href: event_announcement_overview_url(@event)
  xml.id "urn:hcb:announcements_feed_#{@event.public_id}"
  # ^ what can ya do
  xml.generator "HCB", uri: "https://github.com/hackclub/hcb", version: Build.commit_name
  xml.icon rails_blob_url(@event.logo) if @event.logo.present?
  xml.logo rails_blob_url(@event.background_image) if @event.background_image.present?
  # ^ per RFC 4287, "logo" is supposed to refer to something wide?
  @announcements.each do |announcement|
    xml.entry do
      xml.title announcement.title
      xml.id announcement_url(announcement)
      xml.updated announcement.updated_at.xmlschema
      xml.published announcement.published_at.xmlschema
      xml.link rel: "alternate", href: announcement_url(announcement)
      xml.author do
        xml.name announcement.author.initial_name
      end
      xml.content announcement.render_email, type: "html"
    end
  end
end
