# frozen_string_literal: true

# == Schema Information
#
# Table name: announcement_blocks
#
#  id              :bigint           not null, primary key
#  parameters      :jsonb
#  type            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  announcement_id :bigint           not null
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
    self.ignored_columns += ["rendered_html", "rendered_email_html"]

    belongs_to :announcement
    has_one :event, through: :announcement

    before_save { self.parameters ||= {} }

    def render(event: nil, is_email: false)
      if event.present? && event != announcement.event
        Announcements::BlocksController.renderer.render(partial: "announcements/blocks/unknown_block")
      else
        render_html is_email:
      end
    end

    def render_html(is_email: false)
      Announcements::BlocksController.renderer.render(partial:, locals: locals(is_email:))
    end

    def editable?
      true
    end

    def partial
      "announcements/blocks/#{partial_name}"
    end

    def modal
      "announcements/modals/_#{partial_name}"
    end

    def partial_name
      self.class.name.split("::").last.underscore
    end

    def locals(is_email: false)
      custom_locals.merge(is_email:, block: self)
    end

    def custom_locals
      {}
    end

    def empty?
      true
    end

  end

end
