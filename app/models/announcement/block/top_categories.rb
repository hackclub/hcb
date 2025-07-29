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
    class TopCategories < ::Announcement::Block
      before_create :start_date_param
      before_create :end_date_param

      def render_html(is_email: false)
        start_date = start_date_param
        end_date = end_date_param
        event = announcement.event

        categories = BreakdownEngine::Categories.new(event, start_date:, end_date:).run

        Announcements::BlocksController.renderer.render partial: "announcements/blocks/top_categories", locals: { is_email:, block: self, categories:, start_date:, end_date: }
      end

      private

      def start_date_param
        self.parameters["start_date"].present? ? DateTime.parse(self.parameters["start_date"]) : nil
      end

      def end_date_param
        self.parameters["end_date"] ||= Time.now.to_s

        DateTime.parse(self.parameters["end_date"])
      end

    end

  end

end
