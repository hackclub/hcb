# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_balance_observers
#
#  id           :bigint           not null, primary key
#  amount_cents :integer          not null
#  notified_at  :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  ledger_id    :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_ledger_balance_observers_on_ledger_id_and_user_id  (ledger_id,user_id) UNIQUE
#  index_ledger_balance_observers_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (ledger_id => ledgers.id)
#  fk_rails_...  (user_id => users.id)
#
class Ledger
  module Balance
    # A user's request to be emailed when a ledger's available balance drops
    # below amount_cents. Only that user is notified, never the whole team.
    class Observer < ApplicationRecord
      self.table_name = "ledger_balance_observers"

      belongs_to :ledger, class_name: "::Ledger"
      belongs_to :user

      validates :user_id, uniqueness: { scope: :ledger_id }
      validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
      validates :amount_cents, numericality: { less_than: 10_000_000_00, message: "must be less than $10,000,000" }

      monetize :amount_cents

      # A new threshold is a new alert, so it may fire again.
      before_save -> { self.notified_at = nil }, if: :will_save_change_to_amount_cents?
      after_save_commit -> { NotifyObserversJob.perform_later(ledger_id:) }, if: :saved_change_to_amount_cents?

      def self.notify_later(ledgers)
        where(ledger: ledgers).distinct.pluck(:ledger_id).each do |ledger_id|
          NotifyObserversJob.perform_later(ledger_id:)
        end
      end

      # Emails once per drop below the threshold and re-arms once the balance
      # recovers, so a run of small charges on a low balance sends one email.
      def check!(balance_cents:)
        notify = with_lock do
          if balance_cents < amount_cents
            notified_at.nil? && update!(notified_at: Time.current)
          else
            update!(notified_at: nil) if notified_at.present?
            false
          end
        end

        ObserverMailer.with(observer: self, balance_cents:).low_balance.deliver_later if notify
      end

    end
  end

end
