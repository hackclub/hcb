# frozen_string_literal: true

# == Schema Information
#
# Table name: wise_transfers
#
#  id                            :bigint           not null, primary key
#  aasm_state                    :string
#  account_number_bidx           :string
#  account_number_ciphertext     :string
#  address_city                  :string
#  address_line1                 :string
#  address_line2                 :string
#  address_postal_code           :string
#  address_state                 :string
#  amount_cents                  :integer          not null
#  approved_at                   :datetime
#  bank_name                     :string
#  branch_number_bidx            :string
#  branch_number_ciphertext      :string
#  currency                      :string           not null
#  institution_number_bidx       :string
#  institution_number_ciphertext :string
#  memo                          :string           not null
#  payment_for                   :string           not null
#  recipient_birthday_ciphertext :text
#  recipient_country             :integer          not null
#  recipient_email               :string           not null
#  recipient_information         :jsonb
#  recipient_name                :string           not null
#  recipient_phone_number        :text
#  tax_id_bidx                   :string
#  tax_id_ciphertext             :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  event_id                      :bigint           not null
#  user_id                       :bigint           not null
#  wise_id                       :text
#
# Indexes
#
#  index_wise_transfers_on_event_id  (event_id)
#  index_wise_transfers_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class WiseTransfer < ApplicationRecord
  puts "WiseTransfer model loaded"

  include PgSearch::Model
  pg_search_scope :search_recipient, against: [:recipient_name, :recipient_email]


  has_encrypted :account_number, :institution_number, :branch_number, :tax_id
  blind_index :account_number, :institution_number, :branch_number, :tax_id

  validates_length_of :payment_for, maximum: 140

  include AASM
  include Freezable

  include HasWiseRecipient

  belongs_to :event
  belongs_to :user
  has_paper_trail

  has_one :canonical_pending_transaction

  monetize :amount_cents, as: "amount", with_model_currency: :currency

  include PublicActivity::Model
  tracked owner: proc { |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  after_create do
    create_canonical_pending_transaction!(
      event:,
      amount_cents: 0,
      amount_pending: true,
      memo: "#{amount_cents} #{currency} Wise to #{recipient_name}", # this really _really_ sucks. I'm open to ideas here.
      date: created_at
    )
  end

  validates_presence_of :memo, :payment_for, :recipient_name, :recipient_email
  validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }

  aasm timestamps: true, whiny_persistence: true do
    state :pending, initial: true
    state :approved
    state :rejected
    state :sent
    state :deposited
    state :failed
  end

  validates :amount_cents, numericality: { greater_than: 0, message: "must be positive!" }

  alias_attribute :name, :recipient_name

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::WISE_TRANSFER_CODE}-#{id}"
  end

  def local_hcb_code
    return nil unless persisted?

    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

end
