# frozen_string_literal: true

module SearchService
  class Engine
    class Reimbursements
      include SearchService::Shared
      include DynamicFilters

      def initialize(query, user, context)
        @query = query
        @user = user
        @auditor = user.auditor?
        @context = context
      end

      def run
        if @context[:event_id] && @query["types"].length == 1
          reimbursement_reports = Event.find(@context[:event_id]).reimbursement_reports
        elsif @auditor
          reimbursement_reports = Reimbursement::Report
        else
          reimbursement_reports = Reimbursement::Report.where(event: @user.events).and(@user.reimbursement_reports)
        end
        if @context[:user_id] && @query["types"].length == 1
          user = User.find(@context[:user_id])
          reimbursement_reports = reimbursement_reports.where(user:)
        end
        @query["conditions"]&.each do |condition|
          case condition[:property]
          when "date"
            value = Chronic.parse(condition[:value], context: :past)
            filter_by_column(reimbursement_reports, :created_at, condition[:operator], value)
          end
        end
        return reimbursement_reports.search(@query["query"]).first(50)
      end

    end

  end
end
