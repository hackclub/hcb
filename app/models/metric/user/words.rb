# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id           :bigint           not null, primary key
#  metric       :jsonb
#  subject_type :string
#  type         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  subject_id   :bigint
#
# Indexes
#
#  index_metrics_on_subject                               (subject_type,subject_id)
#  index_metrics_on_subject_type_and_subject_id_and_type  (subject_type,subject_id,type) UNIQUE
#
class Metric
  module User
    class Words < Metric
      include Subject

      def calculate
        # 1. Get word frequencies from the User's events
        events_words = user.events.map { |e| ::Metric::Event::Words.from(e).metric }

        # 2. Merge the frequency counts
        events_words = events_words.reduce({}) { |memo, el| memo.merge(el) { |k, old_v, new_v| old_v + new_v } }

        # 3. Sort by frequency
        sort events_words
      end

      def metric
        # JSONB will disregard key order when saving, so we need to sort again
        sort super
      end

      private

      def sort(hash)
        hash.sort_by { |_, value| value }.reverse!.to_h
      end

    end
  end

end
