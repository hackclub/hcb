# frozen_string_literal: true

class WireMailerPreview < ActionMailer::Preview
  def notify_recipient
    WireMailer.with(wire:).notify_recipient
  end

  def notify_failed
    WireMailer.with(wire:, reason: "Beneficiary account is closed").notify_failed
  end

  private

  def wire
    Wire.where.not(column_id: nil).last
  end

end
