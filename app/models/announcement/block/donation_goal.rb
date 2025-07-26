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
    class DonationGoal < ::Announcement::Block
      def render_html(is_email: false)
        goal = announcement.event.donation_goal
        percentage = (goal.progress_amount_cents.to_f / goal.amount_cents) if goal.present?

        Announcements::BlocksController.renderer.render partial: "announcements/blocks/donation_goal", locals: { goal:, percentage:, is_email:, block: self }
      end

    end

  end

end
