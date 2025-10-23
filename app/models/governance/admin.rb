# frozen_string_literal: true

module Governance
  module Admin
    def self.table_name_prefix
      "governance_admin_"
    end

    TRANSFER_APPROVAL_LIMITS = {
      admin: Money.new(5_000_00), # $5k USD
      superadmin: Money.new(200_000_00) # $200k USD
    }.freeze

    class InsufficientApprovalLimitError < Governance::Error; end

    def self.ensure_may_approve_transfer!(user, amount_cents)
      unless may_approve_transfer?(user, amount_cents)
        amount = Money.new(amount_cents)
        role_required = role_required_to_approve_transfer(amount_cents)
        raise InsufficientApprovalLimitError, <<~MSG.squish
          You do not have sufficient permissions to approve a transfer of #{amount.format}.
          Please contact #{role_required} for help.
        MSG
      end
    end

    def self.may_approve_transfer?(user, amount_cents)
      return false unless user&.admin?

      amount = amount_cents.is_a?(Money) ? amount_cents : Money.from_cents(amount_cents)
      amount <= transfer_approval_limit(user)
    rescue KeyError
      Rails.error.unexpected("Unknown access level '#{user.access_level}' for user ID #{user.id} when checking transfer approval limit")

      false
    end

    def self.transfer_approval_limit(user)
      return ArgumentsError.new("User must be an admin") unless user&.admin?

      TRANSFER_APPROVAL_LIMITS.fetch(user.access_level.to_sym)
    end

    def self.role_required_to_approve_transfer(amount_cents)
      amount = amount_cents.is_a?(Money) ? amount_cents : Money.from_cents(amount_cents)

      role, _limit = TRANSFER_APPROVAL_LIMITS.sort_by { |_role, limit| limit }.find { |_role, limit| amount <= limit }

      case role
      when :admin
        "an admin"
      when :superadmin
        "a superadmin"
      when nil
        # Well, no one can approve this transfer! Contact Gary for help.
        "Gary"
      else
        role.to_s.humanize
      end
    end

  end
end
