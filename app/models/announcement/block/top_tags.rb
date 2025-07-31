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
    class TopTags < ::Announcement::Block
      include HasFlexibleStartDate
      include HasEndDate

      delegate :empty?, to: :tags

      def render_html(is_email: false)
        start_date = start_date_param
        end_date = end_date_param

        Announcements::BlocksController.renderer.render partial: "announcements/blocks/top_tags", locals: { is_email:, block: self, tags:, start_date:, end_date: }
      end

      private

      def tags
        start_date = start_date_param
        end_date = end_date_param
        event = announcement.event

        @tags ||= BreakdownEngine::Tags.new(event, start_date:, end_date:).run
      end

    end

  end

end
