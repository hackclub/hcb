# frozen_string_literal: true

module OneTimeJobs
  class DisableAllIncreaseAccountNumbers
    def self.perform
      IncreaseAccountNumber.where.not(event_id: 183).find_each do |ian|
        puts ian.id
        Increase::AccountNumbers.update(ian.increase_account_number_id, status: :disabled)
      end
    end

  end
end
