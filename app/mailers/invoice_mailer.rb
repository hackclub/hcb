# frozen_string_literal: true

class InvoiceMailer < ApplicationMailer
  def notify_organizers_sent
    @invoice = params[:invoice]
    @emails = @invoice.sponsor.event.users.where(organizer_positions: { role: :manager }).map(&:email_address_with_name)
    @emails << @invoice.sponsor.event.config.contact_email if @invoice.sponsor.event.config.contact_email.present?

    mail to: @emails, subject: "#{@invoice.event.name}: #{@invoice.creator.name} sent an invoice to #{@invoice.sponsor.name}"
  end

  def notify_organizers_paid
    @invoice = params[:invoice]
    @emails = @invoice.sponsor.event.users.map(&:email_address_with_name)
    @emails << @invoice.sponsor.event.config.contact_email if @invoice.sponsor.event.config.contact_email.present?
    @emails = @emails.length > 10 ? [@invoice.creator.email_address_with_name] : @emails

    if @invoice.sponsor.event.can_front_balance?
      mail to: @emails, subject: "Payment from #{@invoice.sponsor.name} has arrived 💵"
    else
      mail to: @emails, subject: "Payment from #{@invoice.sponsor.name} is on the way 💵"
    end

  end

end
