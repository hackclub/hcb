# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                      :bigint           not null, primary key
#  average_date_difference :decimal(, )
#  card                    :string
#  hcb_codes               :json
#  last_hcb_code           :string
#  merchant                :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_subscriptions_on_merchant_and_card  (merchant,card) UNIQUE
#
class Subscription < ApplicationRecord
end
