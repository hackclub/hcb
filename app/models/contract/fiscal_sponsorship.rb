# frozen_string_literal: true

# == Schema Information
#
# Table name: contracts
#
#  id                :bigint           not null, primary key
#  aasm_state        :string
#  contractable_type :string
#  cosigner_email    :string
#  deleted_at        :datetime
#  external_service  :integer
#  include_videos    :boolean
#  signed_at         :datetime
#  type              :string           not null
#  void_at           :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  contractable_id   :bigint
#  document_id       :bigint
#  external_id       :string
#
# Indexes
#
#  index_contracts_on_contractable  (contractable_type,contractable_id)
#  index_contracts_on_document_id   (document_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id)
#

class Contract
  class FiscalSponsorship < Contract


  end

end
