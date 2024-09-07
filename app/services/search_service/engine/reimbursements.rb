# frozen_string_literal: true

module SearchService
  class Engine
    class Reimbursements
      include SearchService::Shared
      def initialize(query, user, context)
        @query = query
        @user = user
        @admin = user.admin?
        @context = context
      end

      def run
        if @context[:event_id] && @query["types"].length == 1
          reimbursement_reports = Event.find(@context[:event_id]).reimbursement_reports
        elsif @admin
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
            reimbursement_reports = reimbursement_reports.where("reimbursement_reports.created_at #{condition[:operator]} ?", value)
          end
        end
        return reimbursement_reports.search(@query["query"]).first(50)
      end

    end

  end
end
