# frozen_string_literal: true

# == Schema Information
#
# Table name: announcements
#
#  id            :bigint           not null, primary key
#  aasm_state    :string
#  content       :jsonb            not null
#  deleted_at    :datetime
#  published_at  :datetime
#  template_type :string
#  title         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  author_id     :bigint           not null
#  event_id      :bigint           not null
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
  hashid_config salt: ""

  include AASM

  ALLOWED_URL_SCHEMES = ["http", "https", "mailto", "tel"].freeze
  WHITELISTED_ATTRIBUTES = ["href", "src", "rel", "target", "title", "id", "alt"].freeze

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

  scope :all_monthly, -> { where(template_type: Announcement::Templates::Monthly.name) }
  scope :monthly, -> { all_monthly.joins(event: :config).where("event_configurations.generate_monthly_announcement" => true) }
  scope :all_monthly_for, ->(date) { all_monthly.where("announcements.created_at BETWEEN ? AND ?", date.beginning_of_month, date.end_of_month) }
  scope :monthly_for, ->(date) { monthly.where("announcements.created_at BETWEEN ? AND ?", date.beginning_of_month, date.end_of_month) }
  scope :approved_monthly_for, ->(date) { monthly_for(date).draft }
  validate :content_is_json

  scope :saved, -> { where.not(aasm_state: :template_draft).where.not(content: {}).and(where.not(template_type: Announcement::Templates::Monthly.name, published_at: nil).or(where(template_type: nil))) }

  belongs_to :author, class_name: "User"
  belongs_to :event

  has_many :blocks, dependent: :destroy

  validates :title, presence: true, if: :published?

  before_save :autofollow_organizers

  before_save :remove_unsafe_content

  def render
    ProsemirrorService::Renderer.render_html(content, event)
  end

  def render_email
    ProsemirrorService::Renderer.render_html(content, event, is_email: true)
  end

  private

  def remove_unsafe_content
    return if self.content.blank?

    new_content = ProsemirrorService::Renderer.map_nodes self.content do |node|
      if node["marks"].present?
        new_marks = node["marks"].map do |mark|
          next mark unless mark["attrs"].present?

          mark["attrs"] = whitelist_attrs(mark["attrs"])

          next mark unless mark["attrs"]["href"].present?

          url = URI.parse(URI::RFC2396_PARSER.escape(mark["attrs"]["href"]))

          if Announcement::ALLOWED_URL_SCHEMES.exclude? url.scheme
            mark["attrs"]["href"] = "#"
          end

          mark
        end

        node["marks"] = new_marks
      end

      if node["attrs"].present?
        node["attrs"] = whitelist_attrs(node["attrs"])
      end

      node
    end

    self.content = new_content
  end

  def whitelist_attrs(attrs)
    attrs.select do |attr_key|
      WHITELISTED_ATTRIBUTES.include? attr_key
    end
  end

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
