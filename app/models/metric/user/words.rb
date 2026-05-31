# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id            :bigint           not null, primary key
#  aasm_state    :string
#  canceled_at   :datetime
#  completed_at  :datetime
#  failed_at     :datetime
#  metric        :jsonb
#  processing_at :datetime
#  subject_type  :string
#  type          :string           not null
#  year          :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  subject_id    :bigint
#
# Indexes
#
#  index_metrics_on_subject                                        (subject_type,subject_id)
#  index_metrics_on_subject_type_and_subject_id_and_type_and_year  (subject_type,subject_id,type,year) UNIQUE
#
class Metric
  module User
    class Words < Metric
      include Subject

      def calculate
        # 1. Get word frequencies from the User's events
        events = user.events.to_a
        event_ids = events.map(&:id)

        preloaded_metrics = ::Metric::Event::Words
                            .where(subject_type: "Event", subject_id: event_ids, year: Metric.year)
                            .order(completed_at: :desc, updated_at: :desc)
                            .index_by(&:subject_id)

        events_words = events.map do |e|
          cached = preloaded_metrics[e.id]
          metric = (cached&.completed? ? cached : ::Metric::Event::Words.from(e))
          metric.metric
        end

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
