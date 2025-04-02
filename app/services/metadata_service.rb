# frozen_string_literal: true

class MetadataService

  def initialize
    @transactions = TransactionGroupingEngine::Transaction::All.new(event_id: 183).run.last(100)
  end

  def run
    @transactions.map(&method(:dump))
  end

  def dump(tx)
    hcb_code = tx.local_hcb_code
    self.class.schema.map do |object_name, fields|
      linked_object = hcb_code.send(object_name)
      next dump_unknown(tx) if hcb_code.unknown?
      next if linked_object.nil?

      fields = fields.map do |field_name|
        [field_name, linked_object.send(field_name)]
      end.to_h
      puts fields

      [object_name, fields]
    end.compact.to_h
  end

  def dump_unknown(tx)
    # Unknown TX don't have a linked object; instead we only have data from our
    # underlying bank; nothing more.
    hcb_code = tx.local_hcb_code

    fields = [:amount_cents, :memo].map do |field_name|
      [field_name, hcb_code.send(field_name)]
    end.to_h

    [:unknown, fields]
  end

  def self.schema
    {
      donation: %i[name email amount],
      raw_pending_stripe_transaction: %i[amount_cents date_posted],
      ach_transfer: %i[amount],
      disbursement: %i[amount_cents],
    }
  end

end
