# frozen_string_literal: true

# == Schema Information
#
# Table name: announcement_blocks
#
#  id                  :bigint           not null, primary key
#  parameters          :jsonb
#  rendered_email_html :text
#  rendered_html       :text
#  type                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  announcement_id     :bigint           not null
#
# Indexes
#
#  index_announcement_blocks_on_announcement_id  (announcement_id)
#
# Foreign Keys
#
#  fk_rails_...  (announcement_id => announcements.id)
#
class Announcement
  class Block < ApplicationRecord
    belongs_to :announcement
    has_one :event, through: :announcement

    after_create :refresh!

    def refresh!
      self.parameters ||= {}
      self.rendered_html = render
      self.rendered_email_html = render(is_email: true)

      save!
    end

    def render(event: nil, is_email: false)
      if event.present? && event != announcement.event
        Announcements::BlocksController.renderer.render(partial: "announcements/blocks/unknown_block")
      else
        render_html is_email:
      end
    end

    def render_html(is_email: false)
      Announcements::BlocksController.renderer.render(partial: "announcements/blocks/unknown_block")
    end

  end

end
