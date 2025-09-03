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
  module Event
    class Words < Metric
      include Subject

      def calculate
        # 1. Get memos from event
        transactions = event.canonical_transactions
                            .where("EXTRACT(YEAR FROM date) = 2024")
                            .select("COALESCE(custom_memo, memo) as memo, hcb_code")
                            .to_h { |r| [r.hcb_code, r.memo] }

        event.canonical_pending_transactions
             .where("EXTRACT(YEAR FROM date) = 2024")
             .select("COALESCE(custom_memo, memo) as memo, hcb_code")
             .each { |r| transactions[r.hcb_code] ||= r.memo }

        # 2. Get words from transaction memos
        words = transactions.values.flat_map(&:split)

        # 3. Clean words
        words.map!(&method(:clean))

        # 4. Remove stop words, numbers, and stuff we don't want
        words.reject! { |w| stop_word?(w) || numeric?(w) || !meaningful?(w) }

        # 5. Count them all up
        frequency = words.tally

        # 6. Sort by frequency
        sort frequency
      end

      def metric
        # JSONB will disregard key order when saving, so we need to sort again
        sort super
      end

      private

      def clean(word)
        word.downcase.match(/\A[("]*(.*?)[):,"]*\Z/)[1]
      end

      def stop_word?(str)
        stop_words = %w[the of and to in is for from a]
        boring_words = %w[tax cnd net tst* inc inc.]
        str.in?(stop_words + boring_words)
      end

      def numeric?(str)
        !Float(str).nil? rescue false
      end

      def meaningful?(str)
        # we don't want stuff too short, but we also want emojis
        str.size >= 3 || str.match?(/\A\p{Emoji}\z/)
      end

      def sort(hash)
        hash.sort_by { |_, value| value }.reverse!.to_h
      end

    end
  end

end
