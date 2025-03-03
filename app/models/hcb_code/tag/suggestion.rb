# frozen_string_literal: true

# == Schema Information
#
# Table name: hcb_code_tag_suggestions
#
#  id          :bigint           not null, primary key
#  aasm_state  :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  hcb_code_id :bigint           not null
#  tag_id      :bigint           not null
#
# Indexes
#
#  index_hcb_code_tag_suggestions_on_hcb_code_id  (hcb_code_id)
#  index_hcb_code_tag_suggestions_on_tag_id       (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (hcb_code_id => hcb_codes.id)
#  fk_rails_...  (tag_id => tags.id)
#
class HcbCode
  module Tag
    class Suggestion < ApplicationRecord
      belongs_to :hcb_code
      belongs_to :tag, class_name: "::Tag"

      self.table_name = "hcb_code_tag_suggestions"

      include AASM

      aasm do
        state :suggested, initial: true
        state :accepted
        state :rejected

        event :mark_accepted do
          transitions from: :suggested, to: :accepted
          after do
            unless ::HcbCodeTag.where(tag_id:, hcb_code_id:).any?
              ::HcbCodeTag.create!(tag_id:, hcb_code_id:)
            end
            broadcast_remove_to([tag.event, :tags], target: "tag_suggestion_#{id}")
          end
        end

        event :mark_rejected do
          transitions from: :suggested, to: :rejected
          after do
            broadcast_remove_to([tag.event, :tags], target: "tag_suggestion_#{id}")
          end
        end
      end

    end
  end

end
