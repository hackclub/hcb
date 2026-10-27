# frozen_string_literal: true

class Event
  # Managers review reimbursement reports that have no assigned reviewer.
  # Opt-outs are stored instead of opt-ins, so new managers join
  # automatically. An opt-out follows the organizer position, so it also
  # covers the sub-organizations that position gives access to.
  module HasReimbursementReviewers
    extend ActiveSupport::Concern

    included do
      has_many :reimbursement_reviewer_opt_outs, through: :organizer_positions, source: :reimbursement_reviewer_opt_out

      enum :reimbursement_reviewer_selection, {
        disabled: "disabled",
        optional: "optional",
        required: "required",
      }, prefix: :reviewer_selection
    end

    def eligible_reimbursement_reviewers
      User.where(id: ancestor_organizer_positions.manager_access.select(:user_id))
    end

    # Managers who review reports without an assigned reviewer, including
    # managers of parent organizations.
    def reimbursement_reviewers
      User.where(id: ancestor_organizer_positions.manager_access.where.missing(:reimbursement_reviewer_opt_out).select(:user_id))
    end

    # Managers of parent organizations opt out from their own organization's
    # settings, so they can't be toggled here.
    def inherited_reimbursement_reviewers
      User.where(id: ancestor_organizer_positions.where.not(event_id: id).manager_access.where.missing(:reimbursement_reviewer_opt_out).select(:user_id))
    end

    # This organization's own managers who review, for the settings form
    def reimbursement_reviewer_position_ids
      organizer_positions.manager_access.where.missing(:reimbursement_reviewer_opt_out).ids
    end

    def reimbursement_reviewer_position_ids=(ids)
      ids = ids.compact_blank.map(&:to_i)
      managers = organizer_positions.manager_access

      Event::ReimbursementReviewerOptOut.where(organizer_position: managers.where(id: ids)).destroy_all
      managers.where.not(id: ids).where.missing(:reimbursement_reviewer_opt_out).find_each(&:create_reimbursement_reviewer_opt_out!)
    end
  end

end
