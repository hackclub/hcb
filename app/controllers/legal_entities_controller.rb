# frozen_string_literal: true

class LegalEntitiesController < ApplicationController
  before_action :set_legal_entity, only: [:show, :replace]

  def show
    authorize @legal_entity
  end

  def replace
    authorize @legal_entity

    new_tax_form = @legal_entity.tax_forms.find_by_hashid!(params[:new_tax_form_id])
    authorize new_tax_form, :switch_legal_entity?

    return if reject_unusable_tax_form!(new_tax_form, redirect_to: @legal_entity)

    if new_tax_form.entity_type != @legal_entity.entity_type
      flash[:error] = "That tax form is for a #{new_tax_form.entity_type}, so it can't replace this #{@legal_entity.entity_type} legal entity. Discard it and submit a new one, or create a separate legal entity."
      redirect_to legal_entity_path(@legal_entity)
      return
    end

    new_le = nil

    ActiveRecord::Base.transaction do
      @legal_entity.archive!

      new_le = LegalEntity.create!(
        name: @legal_entity.name,
        tin_hash: new_tax_form.tin_hash,
        entity_type: new_tax_form.entity_type,
        users: @legal_entity.users
      )

      new_tax_form.update!(legal_entity: new_le)

      # The taxpayer's TIN changed, not their bank account. Carry the payout methods
      # over so they don't have to re-enter and re-verify them.
      @legal_entity.payout_methods.each { |payout_method| payout_method.update!(legal_entity: new_le) }

      migrate_pending_payments(from_le: @legal_entity, to_le: new_le, archive_remaining_payees: true)
    end

    redirect_to legal_entity_path(new_le)
  end

  def create_from_tax_form
    tax_form = Tax::Form.find_by_hashid!(params[:new_tax_form_id])
    authorize tax_form, :create_legal_entity?

    old_le = LegalEntity.find_by_hashid(params[:old_le_id])
    authorize old_le, :switch? if old_le.present?

    return if reject_unusable_tax_form!(tax_form, redirect_to: old_le || tax_form.legal_entity)

    new_le = nil

    ActiveRecord::Base.transaction do
      new_le = LegalEntity.create!(
        name: params[:name],
        tin_hash: tax_form.tin_hash,
        entity_type: tax_form.entity_type,
        users: [current_user]
      )

      tax_form.update!(legal_entity: new_le)

      # The old entity stays active here (the payee owns both), so only payments
      # that haven't gone out yet move across.
      migrate_pending_payments(from_le: old_le, to_le: new_le) if old_le.present?
    end

    redirect_to legal_entity_path(new_le)
  end

  private

  def set_legal_entity
    @legal_entity = LegalEntity.find_by_hashid!(params[:id])
  end

  # A form that never completed, or whose import never produced a fingerprint, has
  # no TIN to move to. Creating an entity from one would leave it with a nil
  # tin_hash, which silently drops it out of 1099 aggregation.
  def reject_unusable_tax_form!(tax_form, redirect_to:)
    return false if tax_form.completed? && tax_form.tin_hash.present?

    flash[:error] = "That tax form isn't finished processing yet. Try again in a few minutes."
    redirect_to legal_entity_path(redirect_to)
    true
  end

  # Payments that already went out stay on the old legal entity: they were paid
  # under the old TIN, and that is the TIN the IRS expects on their 1099.
  #
  # Scans every payee, archived or not: an archived payee can still carry a payment
  # stuck in pending_legal_entity (archiving a payee doesn't cancel its payments),
  # and that payment has to move off an entity we're about to archive or it can
  # never be sent.
  def migrate_pending_payments(from_le:, to_le:, archive_remaining_payees: false)
    from_le.payees.find_each do |payee|
      pending = payee.payments.pending_legal_entity.to_a

      if pending.any?
        new_payee = payee.event.payees.find_by(legal_entity: to_le) ||
                    payee.event.payees.create!(
                      display_name: payee.display_name,
                      email: payee.email,
                      legal_entity: to_le
                    )

        # Re-point each payment at the new payee and then re-run the payability
        # check: these have been waiting in pending_legal_entity, and moving them
        # onto an already-payable entity is exactly the moment they can proceed.
        # on_legal_entity_assigned no-ops unless the new entity is payable, so a
        # not-yet-payable target leaves them pending, as before.
        pending.each do |payment|
          payment.update!(payee: new_payee)
          payment.on_legal_entity_assigned
        end
      end

      # When the old entity is being archived, every payee still pointing at it has
      # to go too. Leaving one active lets its organization send a payment that can
      # never be paid out, because an archived legal entity is never payable.
      payee.archive! if !payee.archived? && (archive_remaining_payees || pending.any?)
    end
  end

end
