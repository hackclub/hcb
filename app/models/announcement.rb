# frozen_string_literal: true

# == Schema Information
#
# Table name: announcements
#
#  id           :bigint           not null, primary key
#  content      :text
#  deleted_at   :datetime
#  draft        :boolean
#  published_at :datetime
#  title        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  event_id     :bigint           not null
#  user_id      :bigint
#
# Indexes
#
#  index_announcements_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Announcement < ApplicationRecord
  has_paper_trail
  acts_as_paranoid

  belongs_to :user
  belongs_to :event

  alias_method :author, :user

  def publish
    AnnouncementPublishedJob.new.perform(announcement: self)

    self.draft = false
    self.published_at = Time.now

    save!
  end

  def render_html
    renderer = ProsemirrorToHtml::Renderer.new

    # rubocop:disable Rails/OutputSafety
    renderer.render(JSON.parse(self.content)).html_safe
    # rubocop:enable Rails/OutputSafety
  end

end
