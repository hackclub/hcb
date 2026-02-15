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
  class Block
    class DonationSummary < ::Announcement::Block
      include HasEndDate

      before_create :start_date_param

      delegate :empty?, to: :donations

      def custom_locals
        start_date = start_date_param
        end_date = end_date_param
        total = donations.sum(:amount)

        { donations:, total:, start_date:, end_date: }
      end

      private

      def donations
        start_date = start_date_param
        end_date = end_date_param

        @donations ||= announcement.event.donations.succeeded_and_not_refunded.where(created_at: start_date..end_date)
      end

      def start_date_param
        if self.parameters["start_date"].present?
          DateTime.parse(self.parameters["start_date"])
        else
          self.parameters["start_date"] ||= 1.month.ago.to_date.to_s
          1.month.ago
        end
      end

    end

  end

end
