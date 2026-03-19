# frozen_string_literal: true

# == Schema Information
#
# Table name: comment_hcb_codes
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  comment_id  :bigint           not null
#  hcb_code_id :bigint           not null
#
# Indexes
#
#  index_comment_hcb_codes_on_comment_id                  (comment_id)
#  index_comment_hcb_codes_on_comment_id_and_hcb_code_id  (comment_id,hcb_code_id) UNIQUE
#  index_comment_hcb_codes_on_hcb_code_id                 (hcb_code_id)
#
# Foreign Keys
#
#  fk_rails_...  (comment_id => comments.id)
#  fk_rails_...  (hcb_code_id => hcb_codes.id)
#
class CommentHcbCode < ApplicationRecord
  belongs_to :comment
  belongs_to :hcb_code
end
