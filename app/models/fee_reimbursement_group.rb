# frozen_string_literal: true

# == Schema Information
#
# Table name: fee_reimbursement_groups
#
#  id         :bigint           not null, primary key
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_fee_reimbursement_groups_on_slug  (slug) UNIQUE
#

# Every Stripe fee reimbursement created in the same ISO week is topped up
# under one statement descriptor, and so one HCB code (HCB-900-<week>) and one
# ledger item. The group is that week: each FeeReimbursement finds or creates
# it on create, its ledger item is created "intended" right away, and each
# top-up's bank debit is matched to that item by the short code in its memo.
class FeeReimbursementGroup < ApplicationRecord
  # ISO week-numbering year and week, e.g. "2026_42" — the key the weekly
  # HCB-900 code has always been built from.
  WEEK_FORMAT = "%G_%V"
  WEEK_REGEX = /\A\d{4}_\d{2}\z/

  has_paper_trail

  has_many :fee_reimbursements
  has_one :ledger_item, class_name: "Ledger::Item", as: :linked_object

  validates :slug, presence: true, uniqueness: true, format: { with: WEEK_REGEX }
  # The HCB code every top-up in the group was made under is built from the
  # slug, so it can't change.
  attr_readonly :slug

  after_create_commit :assign_ledger_item!

  def hcb_code
    [
      ::TransactionGroupingEngine::Calculate::HcbCode::HCB_CODE,
      ::TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE,
      slug
    ].join(::TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def event
    Event.find(::EventMappingEngine::EventIds::HACK_CLUB_BANK)
  end

  # Monday of the group's week
  def start_date
    year, week_number = slug.split("_").map(&:to_i)
    Date.commercial(year, week_number, 1)
  end

  def memo
    "🗂️ Stripe fee reimbursements for week of #{start_date.strftime("%-m/%-d")}"
  end

  # The ledger item starts "intended" (no transactions yet) and is matched by
  # short code as each top-up's bank debit comes in. The week's HCB code may
  # already have a ledger item — a top-up that settled before the group existed
  # created one from its transaction — in which case that item is linked rather
  # than duplicated. Idempotent, so the backfill can call it on existing groups.
  def assign_ledger_item!
    return if ledger_item.present?

    safely do
      # TODO: remove HCB code lookup and only search for Ledger::Item
      existing = local_hcb_code.ledger_item || Ledger::Item.find_by(short_code: local_hcb_code.short_code)

      if existing.nil?
        # amount_cents stays 0 until the top-ups' transactions map in. memo and
        # status are recomputed by Ledger::Item#refresh! on create; intended_at
        # preserves the creation time through it (see #calculate_intended_at).
        create_ledger_item!(amount_cents: 0, datetime: created_at, intended_at: created_at, memo:, short_code: local_hcb_code.short_code, hcb_code: local_hcb_code)
      elsif existing.linked_object.nil?
        existing.update!(linked_object: self)
        # Remap as well as refresh: the group now tells the mapper this belongs
        # to Hack Club Bank (see Ledger::Mapper#event_from_linked_object).
        existing.map!
      end
    end
  end

end
