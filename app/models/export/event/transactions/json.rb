# frozen_string_literal: true

# == Schema Information
#
# Table name: exports
#
#  id              :bigint           not null, primary key
#  parameters      :jsonb
#  type            :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  requested_by_id :bigint
#
# Indexes
#
#  index_exports_on_requested_by_id  (requested_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_id => users.id)
#
class Export
  module Event
    module Transactions
      class Json < Export
        store_accessor :parameters, :event_id, :public_only
        def async?
          event.canonical_transactions.size > 300
        end

        def label
          "JSON transaction export for #{event.name}"
        end

        def filename
          "#{event.slug}_transactions_#{Time.now.strftime("%Y%m%d%H%M")}.json"
        end

        def mime_type
          "application/json"
        end

        def content
          event.canonical_transactions.order("date desc").map do |ct|
            row(ct)
          end.to_json
        end

        private

        def event
          @event ||= ::Event.find(event_id)
        end

        def row(ct)
          {
            date: ct.date,
            memo: ct.local_hcb_code.memo,
            amount_cents: public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents,
            tags: ct.local_hcb_code.tags.filter { |tag| tag.event_id == event_id }.pluck(:label).join(", "),
            comments: public_only ? [] : ct.local_hcb_code.comments.not_admin_only.pluck(:content),
            user: if ct.local_hcb_code.author.present?
                    {
                      id: ct.local_hcb_code.author.public_id,
                      name: ct.local_hcb_code.author.name,
                    }
                  else
                    nil
                  end
          }
        end

      end
    end
  end

end
