# frozen_string_literal: true

class User
  class UpdateTeenagerColumnJob < ApplicationJob
    queue_as :low

    def perform
      User.in_batches do |users_relation|
        groups = users_relation.select(:id, :birthday_ciphertext).group_by(&method(:teenager?))
        groups.each do |value, users|
          User.where(id: users.pluck(:id)).update_all(teenager: value)
        end
      end
    end

    def teenager?(user)
      # I'm allowing this method to return true, false, or nil. Allowing nil
      # allows for more accurate stats.
      user.birthday&.after?(19.years.ago)
    end

  end

end
