# frozen_string_literal: true

# == Schema Information
#
# Table name: announcement_blocks
#
#  id                  :bigint           not null, primary key
#  parameters          :jsonb
#  rendered_email_html :text             not null
#  rendered_html       :text             not null
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

    before_create :set_html

    def refresh!
      set_html
      save!
    end

    def render(event: nil, is_email: false)
      if event.present? && event != announcement.event
        Announcement::BlocksController.renderer.render(partial: "announcements/blocks/unknown_block")
      else
        render_html is_email:
      end
    end

    def render_html(is_email: false)
      Announcement::BlocksController.renderer.render(partial: "announcements/blocks/unknown_block")
    end

    private

    def set_html
      self.parameters ||= {}
      self.rendered_html = render
      self.rendered_email_html = render(is_email: true)
    end

  end

end
