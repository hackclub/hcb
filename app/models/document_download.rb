# frozen_string_literal: true

# == Schema Information
#
# Table name: document_downloads
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  ip_address  :inet
#  user_agent  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  document_id :bigint
#  user_id     :bigint
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id)
#  fk_rails_...  (user_id => users.id)
#
class DocumentDownload < ApplicationRecord
  acts_as_paranoid

  belongs_to :document, inverse_of: :downloads
  belongs_to :user

  validates_presence_of :ip_address

  def self.from_request(request, params = {})
    DocumentDownload.new(
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      **params
    )
  end

end
