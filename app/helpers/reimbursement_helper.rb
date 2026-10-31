# frozen_string_literal: true

module ReimbursementHelper
  def movable_reimbursement_report_options(report)
    @movable_reimbursement_report_options ||= {}
    @movable_reimbursement_report_options[report.id] ||= begin # rubocop:disable Rails/HelperInstanceVariable
      reports =
        if admin_signed_in?
          current_user.reimbursement_reports.draft.excluding(report).pluck(:name, :id) +
            Reimbursement::Report.draft.excluding(report).pluck(:name, :id)
        elsif current_user == report.user
          current_user.reimbursement_reports.draft.excluding(report).pluck(:name, :id)
        else
          report.event.reimbursement_reports.draft.excluding(report).pluck(:name, :id)
        end

      reports.uniq
    end
  end
end
