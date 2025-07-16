# frozen_string_literal: true

# == Schema Information
#
# Table name: announcements
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string
#  content             :jsonb            not null
#  deleted_at          :datetime
#  published_at        :datetime
#  rendered_email_html :text
#  rendered_html       :text
#  title               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  author_id           :bigint           not null
#  event_id            :bigint           not null
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
  include AASM

  has_paper_trail
  acts_as_paranoid

  aasm timestamps: true do
    # When we create a template and prompt it to users, it's in this
    # `template_draft` so that it's "unlisted" on the index page.
    state :template_draft

    state :draft, initial: true
    state :published

    event :mark_published do
      transitions from: :draft, to: :published

      after do
        AnnouncementPublishedJob.perform_later(announcement: self)
      end
    end

    event :mark_draft do
      transitions from: :template_draft, to: :draft
    end
  end

  scope :saved, -> { where.not(aasm_state: :template_draft) }

  validates :content, presence: true

  belongs_to :author, class_name: "User"
  belongs_to :event

  before_save do
    if content_changed?
      self.rendered_html = ProsemirrorService::Renderer.render_html(content, event)

      if draft?
        self.rendered_email_html = ProsemirrorService::Renderer.render_html(content, event, is_email: true)
      end
    end
  end

end
