# frozen_string_literal: true

class ContractorPolicy < ApplicationPolicy
  def show?
    # Viewing a single contractor exposes rate, invoices, and payment history.
    EventPolicy.new(user, record).contractor_details?
  end

  def new?
    EventPolicy.new(user, record).new_contractor?
  end

  def create?
    EventPolicy.new(user, record).create_contractor?
  end

  # Reviewing (approving/rejecting) invoices requires the same access as
  # creating a contractor payment — i.e. an admin or manager.
  def review?
    EventPolicy.new(user, record).create_contractor?
  end

end
