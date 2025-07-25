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
#  template_type       :string
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
        Announcement::PublishedJob.perform_later(announcement: self)
      end
    end

    event :mark_draft do
      transitions from: :template_draft, to: :draft
    end
  end

  scope :saved, -> { where.not(aasm_state: :template_draft) }
  scope :monthly, -> { where(template_type: Announcement::Templates::Monthly.name) }
  scope :monthly_for, ->(date) { monthly.where("announcements.created_at BETWEEN ? AND ?", date.beginning_of_month, date.end_of_month) }
  validate :content_is_json

  scope :saved, -> { where.not(aasm_state: :template_draft).where.not(content: {}) }

  belongs_to :author, class_name: "User"
  belongs_to :event

  validates :title, presence: true, if: :published?

  before_save :autofollow_organizers

  def render
    ProsemirrorService::Renderer.render_html(content, event)
  end

  def render_email
    ProsemirrorService::Renderer.render_html(content, event, is_email: true)
  end

  private

  def autofollow_organizers
    # is this the first announcement to be published?
    if published? && event.announcements.published.none?
      event.users.excluding(event.followers).find_each do |user|
        event.event_follows.create!(user:)

      rescue ActiveRecord::RecordNotUnique
        # Do nothing. The user already follows this event.
      end
    end
  end

  def content_is_json
    unless content.is_a?(Hash)
      Rails.error.unexpected("Announcement #{id}'s content is not a Hash")
      errors.add(:content, "is invalid")
    end
  end

end
