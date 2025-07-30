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
      before_create :start_date_param
      before_create :end_date_param

      def custom_locals
        start_date = start_date_param
        end_date = end_date_param

        donations = announcement.event.donations.where(aasm_state: [:in_transit, :deposited], created_at: start_date..end_date).order(:created_at)
        total = donations.sum(:amount)

        { donations:, total:, start_date:, end_date: }
      end

      def editable
        true
      end

      private

      def start_date_param
        self.parameters["start_date"] ||= 1.month.ago.to_s

        Date.parse(self.parameters["start_date"])
      end

      def end_date_param
        self.parameters["end_date"] ||= Time.now.to_s

        Date.parse(self.parameters["end_date"])
      end

    end

  end

end
