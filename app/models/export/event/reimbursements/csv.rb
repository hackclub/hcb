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
    module Reimbursements
      class Csv < Export
        store :parameters, accessors: %w[event_id]
        def async?
          false
        end

        def label
          "CSV reimbursements export for #{event.name}"
        end

        def filename
          "#{event.slug}_reimbursements_#{Time.now.strftime("%Y%m%d%H%M")}.csv"
        end

        def mime_type
          "text/csv"
        end

        def content
          Enumerator.new do |y|
            y << header.to_s
        
            reports.each do |rr|
              y << row(rr).to_s
            end
          end
        end
        
        private
        
        def reports
          event.reimbursement_reports.visible.order(created_at: :asc).includes(
            :user,
            :expenses,
            :payout_holding,
          )
        end
        
        def row(rr)
          ::CSV::Row.new(
            headers,
            [
              rr.created_at,
              rr.status_text,
              rr.name,
              rr.amount_cents,
              rr.user.name,
              rr.user.email
            ]
          )
        end
        
        def header
          ::CSV::Row.new(headers, headers, true)
        end
        
        def headers
          [:date, :status, :name, :amount_cents, :reimbursee_name, :reimbursee_email]
        end

        def event
          @event ||= ::Event.find(event_id)
        end

      end
    end
  end

end
