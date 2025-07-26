# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_topups
#
#  id                   :bigint           not null, primary key
#  amount_cents         :integer          not null
#  description          :string           not null
#  metadata             :jsonb
#  statement_descriptor :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  stripe_id            :string
#
# Indexes
#
#  index_stripe_topups_on_stripe_id  (stripe_id) UNIQUE
#
class StripeTopup < ApplicationRecord
  after_create_commit unless: -> { stripe_id.present? } do
    topup = StripeService::Topup.create(
      amount: amount_cents,
      currency: "usd",
      statement_descriptor:,
      description:,
      metadata:
    )
    update!(stripe_id: topup.id)
  end

end
