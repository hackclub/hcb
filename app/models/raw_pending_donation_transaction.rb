# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_donation_transactions
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer
#  date_posted             :date
#  state                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  donation_transaction_id :string
#
class RawPendingDonationTransaction < ApplicationRecord
  monetize :amount_cents

  def date
    date_posted
  end

  def memo
    "Donation"
  end

  def likely_event_id
    @likely_event_id ||= donation.event.id
  end

  def donation
    @donation ||= ::Donation.find_by(id: donation_transaction_id)
  end

end
