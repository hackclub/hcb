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
    class DonationSummary < ::Announcement::Block
      def render_html(is_email: false)
        start_date = parameters["start_date"].present? ? Date.parse(parameters["start_date"]) : 1.month.ago
        donations = announcement.event.donations.where(aasm_state: [:in_transit, :deposited], created_at: start_date..).order(:created_at)
        total = donations.sum(:amount)

        Announcements::BlocksController.renderer.render partial: "announcements/blocks/donation_summary", locals: { donations:, total:, start_date:, is_email:, block: self }
      end

    end

  end

end
