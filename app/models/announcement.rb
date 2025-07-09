# frozen_string_literal: true

# == Schema Information
#
# Table name: announcements
#
#  id           :bigint           not null, primary key
#  content      :text             not null
#  deleted_at   :datetime
#  published_at :datetime
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  author_id    :bigint           not null
#  event_id     :bigint           not null
#
# Indexes
#
#  index_announcements_on_author_id  (author_id)
#  index_announcements_on_event_id   (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id)
#  fk_rails_...  (event_id => events.id)
#
class Announcement < ApplicationRecord
  include Hashid::Rails
  has_paper_trail
  acts_as_paranoid

  validates :content, presence: true

  belongs_to :author, class_name: "User"
  belongs_to :event

  scope :published, -> { where.not(published_at: nil) }

  def publish!
    AnnouncementPublishedJob.perform_later(announcement: self)

    update!(published_at: Time.now)
  end

  def render_html
    renderer = ProsemirrorToHtml::Renderer.new

    # rubocop:disable Rails/OutputSafety
    renderer.render(JSON.parse(self.content)).html_safe
    # rubocop:enable Rails/OutputSafety
  end

  def draft?
    published_at.nil?
  end

  def published?
    !draft?
  end

end
