# frozen_string_literal: true

module Payment
  extend ActiveSupport::Concern
  included do
    belongs_to :payment_recipient, optional: true

    validate { errors.add(:base, "Recipient must be in the same org") if payment_recipient && event != payment_recipient.event }

    before_validation :set_fields_from_payment_recipient, if: -> { payment_recipient.present? }, on: :create
    before_create :create_payment_recipient, if: -> { payment_recipient_id.nil? }

    after_create :update_payment_recipient

    def payment_recipient_attributes
      # This method should be overwritten in specific classes
      raise NotImplementedError, "The #{self.class.name} model includes Payment, but hasn't implemented payment_recipient_attributes."
    end

    def set_fields_from_payment_recipient
      self.payment_recipient_attributes.each do |attribute|
        self[attribute] ||= payment_recipient&.send(attribute)
      end
      self.recipient_name ||= payment_recipient&.name
      self.recipient_email ||= payment_recipient&.email
    end

    def create_payment_recipient
      information = {}

      self.payment_recipient_attributes.each do |attribute|
        information[attribute] ||= self[attribute]
      end

      create_payment_recipient!(
        event:,
        name: recipient_name,
        email: recipient_email,
        information:,
        payment_model: self.class.name
      )
    end

    def update_payment_recipient
      information = {}

      self.payment_recipient_attributes.each do |attribute|
        information[attribute] ||= self[attribute]
      end

      payment_recipient.update!(
        name: recipient_name,
        email: recipient_email,
        information:,
        payment_model: self.class.name
      )
    end
  end

end
