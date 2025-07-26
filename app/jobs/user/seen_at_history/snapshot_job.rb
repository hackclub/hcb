# frozen_string_literal: true

class User
  class SeenAtHistory
    class SnapshotJob < ApplicationJob
      queue_as :low

      def perform
        ::User::SeenAtHistory.insert_all(records)
      end

      def records
        users.map do |u|
          {
            user_id: u.id,
            period_start_at: period_start,
            period_end_at: period_end
          }
        end
      end

      def users
        ::User.joins(:user_sessions).where("user_sessions.last_seen_at between ? and ?", period_start, period_end).distinct
      end

      def period_start
        period_end - ::User::SeenAtHistory::PERIOD_DURATION
      end

      def period_end
        @period_end ||= Time.current
      end

    end

  end

end
