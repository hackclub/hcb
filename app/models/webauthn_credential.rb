# frozen_string_literal: true

# == Schema Information
#
# Table name: webauthn_credentials
#
#  id                 :bigint           not null, primary key
#  authenticator_type :integer
#  name               :string
#  public_key         :string
#  sign_count         :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :bigint           not null
#  webauthn_id        :string
#
# Indexes
#
#  index_webauthn_credentials_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class WebauthnCredential < ApplicationRecord
  belongs_to :user

  enum :authenticator_type, { platform: 0, cross_platform: 1 }

  validates :name, presence: true
  validates :webauthn_id, presence: true
  validates :public_key, presence: true
  validates :sign_count, presence: true

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| record.user }, recipient: proc { |controller, record| record.user }, only: [:create, :destroy]

end
