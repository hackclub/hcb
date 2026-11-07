# frozen_string_literal: true

module Maintenance
  # One-time rollout for hackclub/hcb#15602. Card grant recipients may only
  # pick a reviewer when converting a grant to a reimbursement report if the
  # org's card grant setting allows it, and the column ships off by default.
  # HQ asked to keep the picker, so opt their orgs in.
  class EnableReviewerSelectionForHqCardGrantsTask < MaintenanceTasks::Task
    def collection
      Event.joins(:plan).where(event_plans: { type: Event::Plan::HackClubHQ.sti_name })
    end

    def process(event)
      CardGrantSetting.find_or_create_by!(event:).update!(reviewer_selection_enabled: true)
    end

  end
end
