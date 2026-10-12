# frozen_string_literal: true

# == Schema Information
#
# Table name: login_attempts
#
#  id         :bigint           not null, primary key
#  factor     :string           not null
#  ip_address :inet
#  status     :string           default("pending"), not null
#  user_agent :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  login_id   :bigint           not null
#
# Indexes
#
#  index_login_attempts_on_created_at  (created_at)
#  index_login_attempts_on_login_id    (login_id)
#
# Foreign Keys
#
#  fk_rails_...  (login_id => logins.id)
#
class Login
  class Attempt < ApplicationRecord
    belongs_to :login
    has_one :user, through: :login

    enum :factor, { email: "email" }
    enum :status, { pending: "pending", failed: "failed", succeeded: "succeeded", blocked: "blocked" }

    scope :counted, -> { where(status: [:pending, :failed]) }

    def clear_ip_metadata!
      update!(ip_address: nil, user_agent: nil)
    end

  end

end
