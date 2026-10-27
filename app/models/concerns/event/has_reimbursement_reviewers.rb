# frozen_string_literal: true

class Event
  # Managers review reimbursement reports that have no assigned reviewer.
  # Managers are opted in to their own organization automatically (see
  # OrganizerPosition); managers of a parent organization opt in to each
  # sub-organization themselves.
  module HasReimbursementReviewers
    extend ActiveSupport::Concern

    included do
      has_many :reimbursement_reviewer_opt_ins, class_name: "Event::ReimbursementReviewer::OptIn", dependent: :destroy

      enum :reimbursement_reviewer_selection, {
        disabled: "disabled",
        optional: "optional",
        required: "required",
      }, prefix: :reviewer_selection
    end

    def eligible_reimbursement_reviewers
      User.where(id: ancestor_organizer_positions.manager_access.select(:user_id))
    end

    # Managers who review reports without an assigned reviewer
    def reimbursement_reviewers
      User.where(id: reimbursement_reviewer_positions.select(:user_id))
    end

    def reimbursement_reviewer_positions
      OrganizerPosition.manager_access.where(id: reimbursement_reviewer_opt_ins.select(:organizer_position_id))
    end

    def reimbursement_reviewer_position_ids
      reimbursement_reviewer_positions.ids
    end

    # Managers listed on the settings page: this organization's own, plus
    # managers of parent organizations who aren't already managers here
    def reimbursement_reviewer_candidates
      positions = ancestor_organizer_positions.manager_access
      positions.where(event_id: id).or(positions.where.not(user_id: organizer_positions.manager_access.select(:user_id)))
    end

    # Anyone who can edit the settings toggles this organization's own
    # managers, but managers of a parent organization only toggle themselves.
    def reimbursement_reviewer_candidates_toggleable_by(user)
      candidates = reimbursement_reviewer_candidates
      candidates.where(event_id: id).or(candidates.where(user:))
    end

    # Opts each of `positions` in or out according to whether its id is in
    # `opted_in_ids`. Adds an error and changes nothing if that would leave
    # nobody to review.
    def update_reimbursement_reviewers(positions, opted_in_ids)
      opted_in_ids = opted_in_ids.compact_blank.map(&:to_i)

      if opted_in_ids.empty? && positions.exists? && !reimbursement_reviewer_opt_ins.where.not(organizer_position: positions).exists?
        errors.add(:base, "Select at least one reviewer")
        return false
      end

      transaction do
        reimbursement_reviewer_opt_ins.where(organizer_position: positions.where.not(id: opted_in_ids)).destroy_all
        positions.where(id: opted_in_ids).where.not(id: reimbursement_reviewer_opt_ins.select(:organizer_position_id)).find_each do |position|
          reimbursement_reviewer_opt_ins.create!(organizer_position: position)
        end
      end

      true
    end
  end

end
