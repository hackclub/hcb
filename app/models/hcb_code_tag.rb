# frozen_string_literal: true

# == Schema Information
#
# Table name: hcb_codes_tags
#
#  created_at  :datetime
#  updated_at  :datetime
#  hcb_code_id :bigint           not null, primary key
#  tag_id      :bigint           not null, primary key
#
# Indexes
#
#  index_hcb_codes_tags_on_hcb_code_id_and_tag_id  (hcb_code_id,tag_id) UNIQUE
#
class HcbCodeTag < ApplicationRecord
  self.table_name = "hcb_codes_tags"
  self.primary_key = [:hcb_code_id, :tag_id]

  after_create_commit { broadcast_render_later_to([event, :tags], partial: "tags/create", locals: { hcb_code:, tag:, streamed: true }) }
  after_destroy_commit { broadcast_render_to([event, :tags], partial: "tags/destroy", locals: { hcb_code:, tag:, streamed: true }) }

  belongs_to :hcb_code
  belongs_to :tag
  has_one :event, through: :tag

end
