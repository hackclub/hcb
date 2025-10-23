# frozen_string_literal: true

class SuggestedPairingPolicy < ApplicationPolicy
  def ignore?
    record.receipt.user == user && record.receipt.receiptable.nil?
  end

  def accept?
    record.receipt.user == user && record.receipt.receiptable.nil?
  end

  def accept_with_memo?
    record.receipt.user == user && record.receipt.receiptable.nil?
  end

end
