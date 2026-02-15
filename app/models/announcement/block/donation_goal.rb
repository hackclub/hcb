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
    class DonationGoal < ::Announcement::Block
      before_create :goal_param

      def custom_locals
        percentage = (goal.progress_amount_cents.to_f / goal.amount_cents) if goal.present?

        { goal:, percentage: }
      end

      def empty?
        goal.nil?
      end

      def editable?
        false
      end

      private

      def goal
        @goal ||= Donation::Goal.find_by(event: announcement.event, id: goal_param) || announcement.event.donation_goal
      end

      def goal_param
        self.parameters["goal"] ||= announcement.event.donation_goal&.id
      end

    end

  end

end
