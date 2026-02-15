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
    class TopMerchants < ::Announcement::Block
      include HasFlexibleStartDate
      include HasEndDate

      delegate :empty?, to: :merchants

      def custom_locals
        start_date = start_date_param
        end_date = end_date_param

        { merchants:, start_date:, end_date: }
      end

      private

      def merchants
        start_date = start_date_param
        end_date = end_date_param
        event = announcement.event

        @merchants ||= BreakdownEngine::Merchants.new(event, start_date:, end_date:).run
      end

    end

  end

end
