# frozen_string_literal: true

# Batch lookup by hashid, alongside the gem's single-record `find_by_hashid`.
#
# This lives on the gem's `ClassMethods` rather than on `ApplicationRecord`
# because hashid-rails ships no railtie: models opt in with `include
# Hashid::Rails`. Extending `ClassMethods` reaches exactly those models, plus
# their relations and `has_many` associations, which the gem extends too.
module HashidQueryable
  # A signed hashid for a bigint id is at most 15 characters. Hashids decodes in
  # time quadratic to input length (16k characters is ~1.5s of CPU), so reject
  # over-long strings before decoding rather than after.
  MAX_HASHID_LENGTH = 32

  # Unbounded batch lookup is a table-dump primitive, and decode cost is linear
  # in the count. Raise rather than truncate: a caller that silently drops the
  # tail of a bulk action is worse than one that fails loudly.
  MAX_HASHID_BATCH = 1_000

  # Batch counterpart to `find_by_hashid`, for loading many records in one query
  # rather than one query per hashid.
  #
  # This is a set lookup, not a `map`: the result is unordered, de-duplicated,
  # and silently omits hashids that don't resolve. It is not a drop-in for
  # `find_by_hashid!` — callers that must reject an unknown id have to compare
  # counts themselves.
  #
  # The relation is NOT scoped to an owner. Scope it (`event.payees
  # .where_hashid(...)`) or `policy_scope` it before exposing the records.
  #
  # Input is assumed to be user-supplied: anything that isn't a hashid this
  # model can decode is dropped, so a wholly invalid list matches nothing rather
  # than everything. Raw database ids are dropped too; callers must pass hashids.
  def where_hashid(hashids)
    # Deliberately not `Array.wrap`: it calls `to_ary`, so passing a relation by
    # mistake would load the whole table before discarding it.
    candidates = (hashids.is_a?(Array) ? hashids : [hashids]).grep(String)
    # `hashid_decode` rescues only `Hashids::InputError`, so invalid UTF-8 would
    # otherwise escape as `ArgumentError` from `String#tr`.
    candidates = candidates.select { |hashid| hashid.length <= MAX_HASHID_LENGTH && hashid.valid_encoding? }

    if candidates.size > MAX_HASHID_BATCH
      raise ArgumentError, "too many hashids (#{candidates.size} > #{MAX_HASHID_BATCH})"
    end

    # `uniq` because Postgres estimates row count from the IN list's length, not
    # its distinct count: repeating one id 50k times flips the primary key index
    # scan to a sequential scan.
    where(id: decode_id(candidates).compact.uniq)
  end
end

ActiveSupport.on_load(:active_record) do
  Hashid::Rails::ClassMethods.module_eval do
    def hashid_configuration
      if is_a?(ActiveRecord::Relation) && klass.respond_to?(:hashid_configuration)
        klass.hashid_configuration
      else
        @hashid_configuration || hashid_config
      end
    end
  end

  # As of hashid-rails 1.4.1 the gem defines no `where_hashid`; if it ever does,
  # this include leaves the gem's version winning rather than silently shadowing it.
  Hashid::Rails::ClassMethods.include(HashidQueryable)
end

Hashid::Rails.configure do |config|
  config.salt = Credentials.fetch(:HASHID_SALT)
end
