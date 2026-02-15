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
    class TopCategories < ::Announcement::Block
      include HasFlexibleStartDate
      include HasEndDate

      delegate :empty?, to: :categories

      def custom_locals
        start_date = start_date_param
        end_date = end_date_param

        { categories:, start_date:, end_date: }
      end

      private

      def categories
        start_date = start_date_param
        end_date = end_date_param
        event = announcement.event

        @categories ||= BreakdownEngine::Categories.new(event, start_date:, end_date:).run
      end

    end

  end

end
