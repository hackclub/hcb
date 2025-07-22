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
      before_create do
        start_date_param
        end_date_param

        self
      end

      def render_html(is_email: false)
        start_date = start_date_param
        end_date = end_date_param
        donations = announcement.event.donations.where(aasm_state: [:in_transit, :deposited], created_at: start_date..end_date).order(:created_at)
        total = donations.sum(:amount)

        Announcements::BlocksController.renderer.render partial: "announcements/blocks/donation_summary", locals: { donations:, total:, start_date:, end_date:, is_email:, block: self }
      end

      private

      def start_date_param
        if self.parameters["start_date"].present?
          Date.parse(self.parameters["start_date"])
        else
          self.parameters["start_date"] = 1.month.ago
        end
      end

      def end_date_param
        if self.parameters["end_date"].present?
          Date.parse(self.parameters["end_date"])
        else
          self.parameters["end_date"] = Time.now
        end
      end

    end

  end

end
