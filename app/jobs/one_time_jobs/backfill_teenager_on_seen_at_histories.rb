# frozen_string_literal: true

module OneTimeJobs
  class BackfillTeenagerOnSeenAtHistories < ApplicationJob
    def perform
      User.where.not(birthday_ciphertext: nil).find_each do |user|
        histories = User::SeenAtHistory.where(user_id: user.id)
        next if histories.empty?

        if user.teenager?
          # User is currently a teenager so they've always been a teenager
          histories.update_all(teenager: true)
        else
          # User is 18+, calculate when they turned 18
          eighteenth_birthday = user.birthday.to_date + 18.years

          # Records before their 18th birthday: teenager = true
          histories.where(period_end_at: ...eighteenth_birthday).update_all(teenager: true)

          # Records on or after their 18th birthday: teenager = false
          histories.where(period_end_at: eighteenth_birthday..).update_all(teenager: false)
        end
      end
    end

  end
end
