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
    class HcbCode < ::Announcement::Block
      validate :hcb_code_in_event

      def custom_locals
        { hcb_code:, event: announcement.event }
      end

      def empty?
        hcb_code.nil?
      end

      private

      def hcb_code
        @hcb_code ||= ::HcbCode.find_by_hashid(parameters["hcb_code"])

        unless @hcb_code&.event == announcement.event
          @hcb_code = nil
        end

        @hcb_code
      end

      def hcb_code_in_event
        hcb_code = ::HcbCode.find_by_hashid(parameters["hcb_code"])

        if hcb_code.nil? || hcb_code.event != announcement.event
          errors.add(:base, "Transaction can not be found.")
        end
      end

    end

  end

end
