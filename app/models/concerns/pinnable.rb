      
      
      
      validate :validate_max_pins_for_event, on: :create
      validate :validate_pinnable, on: :create
      
      def validate_max_pins_for_event
        # When event is nil, validate_pinnable already catches it via pinnable?, so no error coverage is lost.
        return if event.nil?

        count = event.pinned_ledger_items.size
        count += 1 if new_record?

        if count > 4
          errors.add(:base, "You can only pin up to four transactions.")
        end
      end

      def validate_pinnable
        unless ledger_item.pinnable?
          errors.add(:base, "At the moment, this transaction can't be pinned.")
        end
      end