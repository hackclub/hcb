# frozen_string_literal: true

module HasTransferRecord
  extend ActiveSupport::Concern

  included do
    class_attribute :transfer_record_config, default: {
      deposited_states: [],
      canceled_states: [],
      event_method: :event,
      name_method: nil,
      email_method: :recipient_email,
      amount_method: :amount
    }

    has_one :transfer_record, as: :transferable, dependent: :destroy

    after_create :sync_transfer_record!
    after_save :sync_transfer_record!, if: :needs_sync?
  end

  class_methods do
    def transfer_record_statuses(deposited: [], canceled: [], event: :event, name: nil, email: :recipient_email, amount: :amount)
      self.transfer_record_config = {
        deposited_states: Array(deposited),
        canceled_states: Array(canceled),
        event_method: event,
        name_method: name,
        email_method: email,
        amount_method: amount
      }
    end
  end

  def transfer_record_status
    config = self.class.transfer_record_config

    return :deposited if any_state_matches?(config[:deposited_states])
    return :canceled if any_state_matches?(config[:canceled_states])

    :in_transit
  end

  private

  def sync_transfer_record!
    return if skip_transfer_record?

    attrs = build_transfer_record_attributes

    if transfer_record
      transfer_record.update!(attrs)
    else
      create_transfer_record!(attrs.merge(created_at:))
    end
  end

  def skip_transfer_record?
    return false unless is_a?(Disbursement)

    source_subledger&.card_grant.present? ||
      destination_subledger&.card_grant.present?
  end

  def build_transfer_record_attributes
    config = self.class.transfer_record_config

    {
      event: send(config[:event_method]),
      recipient_name: get_recipient_name(config),
      recipient_email: get_recipient_email(config),
      amount_cents: get_amount_cents(config),
      status: transfer_record_status
    }
  end

  def get_recipient_name(config)
    return try(config[:name_method]) if config[:name_method]

    try(:recipient_name) || try(:name)
  end

  def get_recipient_email(config)
    return nil unless config[:email_method]

    try(config[:email_method])
  end

  def get_amount_cents(config)
    return 0 unless config[:amount_method]

    if config[:amount_method].respond_to?(:call)
      instance_exec(&config[:amount_method])
    else
      try(config[:amount_method]) || 0
    end
  end

  def any_state_matches?(states)
    states.any? { |state| try("#{state}?") }
  end

  def needs_sync?
    return true if saved_change_to_attribute?(:aasm_state)
    return false unless amount_changed?

    true
  end

  def amount_changed?
    config = self.class.transfer_record_config
    return false unless config[:amount_method]

    if config[:amount_method].respond_to?(:call)
      previous_changes.keys.any? { |key| key.to_s.include?("amount") }
    else
      saved_change_to_attribute?(config[:amount_method])
    end
  end
end
