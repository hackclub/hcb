# frozen_string_literal: true

# == Schema Information
#
# Table name: user_seen_at_histories
#
#  id              :bigint           not null, primary key
#  period_end_at   :datetime         not null
#  period_start_at :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint
#
# Indexes
#
#  index_user_seen_at_histories_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class User
  # This table stores a history of Users' UserSession#last_seen_at.
  # The data is sampled every 30 minutes using a cron job, but the sample
  # collects data from the past hour (PERIOD_DURATION). Sampling more often
  # prevents us from missing data in case the hourly job is delayed.
  # In order to accurately query this data, choose a time unit (e.g. hour) and
  # filter out duplicate users within a given time unit.
  #
  # Ex.
  # ```sql
  # SELECT distinct (date_trunc('hour', period_end_at), user_id) FROM "user_seen_at_histories"
  # ```
  class SeenAtHistory < ApplicationRecord
    PERIOD_DURATION = 1.hour

  end

end
