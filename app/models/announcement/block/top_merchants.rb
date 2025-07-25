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
    class TopMerchants < ::Announcement::Block
      has_one_attached :chart

      def render_html(is_email: false)
        start_date = parameters["start_date"].present? ? Date.parse(parameters["start_date"]) : 1.month.ago

        event = announcement.event

        merchants = BreakdownEngine::Merchants.new(event).run

        Announcements::BlocksController.renderer.render partial: "announcements/blocks/top_merchants", locals: { is_email:, block: self, merchants: }
      end

    end

  end

end
