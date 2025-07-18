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
  class Block
    class HcbCode < ::Announcement::Block
      def render_html(is_email: false)
        hcb_code = ::HcbCode.find_by_hashid(parameters["hcb_code"])

        unless hcb_code&.event == announcement.event
          hcb_code = nil
        end

        Announcements::BlocksController.renderer.render partial: "announcements/blocks/hcb_code", locals: { hcb_code:, event: announcement.event, is_email:, block: self }
      end

    end

  end

end
