# frozen_string_literal: true

require "rails_helper"

# Verifies the hashid extensions added in config/initializers/hashid.rb.
RSpec.describe HashidQueryable do
  let!(:users) { create_list(:user, 3) }
  let(:hashids) { users.map(&:hashid) }

  def user_query_count(&block)
    count = 0
    callback = ->(*, payload) { count += 1 if payload[:sql].include?(%("users")) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    count
  end

  describe ".where_hashid" do
    it "returns every record matching the given hashids" do
      expect(User.where_hashid(hashids)).to match_array(users)
    end

    it "loads the records in a single query" do
      count = user_query_count { User.where_hashid(hashids).to_a }

      expect(count).to eq(1)
    end

    it "accepts a single hashid" do
      expect(User.where_hashid(users.first.hashid)).to contain_exactly(users.first)
    end

    it "returns a relation that can be chained further" do
      expect(User.where_hashid(hashids).where(id: users.first.id)).to contain_exactly(users.first)
    end

    it "is available on associations" do
      event = create(:event)
      payees = create_list(:payee, 2, event:)
      create(:payee)

      expect(event.payees.where_hashid(payees.map(&:hashid))).to match_array(payees)
    end

    it "keeps the conditions of the relation it is called on" do
      event = create(:event)
      active = create(:payee, event:)
      archived = create(:payee, event:, archived_at: Time.current)

      expect(event.payees.not_archived.where_hashid([active, archived].map(&:hashid))).to contain_exactly(active)
    end

    it "matches a record once when its hashid is repeated" do
      expect(User.where_hashid([users.first.hashid] * 3)).to contain_exactly(users.first)
    end

    it "does not preserve the order of the given hashids" do
      # This is a set lookup; callers needing input order must re-sort themselves.
      expect(User.where_hashid(hashids.reverse).map(&:id)).to eq(users.map(&:id).sort)
    end

    describe "input this model cannot decode" do
      it "skips a hashid built from characters outside the alphabet" do
        expect(User.where_hashid([users.first.hashid, "not-a-real-hashid"])).to contain_exactly(users.first)
      end

      it "skips a well formed hashid that fails the checksum" do
        expect(User.where_hashid([users.first.hashid, "zzzzzz"])).to contain_exactly(users.first)
      end

      it "does not decode another model's hashid" do
        event = create(:event)

        expect(User.where_hashid([event.hashid])).to be_empty
      end

      it "returns no records when none of the hashids decode" do
        expect(User.where_hashid(["zzzzzz"])).to be_empty
      end

      it "does not compare against a null id for hashids it skips" do
        sql = User.where_hashid([users.first.hashid, "zzzzzz"]).to_sql

        expect(sql).not_to include("IS NULL")
      end

      it "skips a hashid that decodes beyond the range of the id column" do
        expect(User.where_hashid([users.first.hashid, User.encode_id(2**63)])).to contain_exactly(users.first)
      end

      it "skips a hashid containing invalid UTF-8 rather than raising" do
        expect(User.where_hashid([(+"b9YtZ\xFF").force_encoding("UTF-8")])).to be_empty
      end
    end

    describe "input that is not a hashid at all" do
      it "returns no records for an empty list" do
        expect(User.where_hashid([])).to be_empty
      end

      it "returns no records for a nil list" do
        expect(User.where_hashid(nil)).to be_empty
      end

      it "does not accept raw database ids" do
        expect(User.where_hashid(users.map(&:id))).to be_empty
      end

      it "does not accept stringified raw database ids" do
        expect(User.where_hashid(users.map { |user| user.id.to_s })).to be_empty
      end

      it "does not accept a symbol that stringifies to a hashid" do
        expect(User.where_hashid([users.first.hashid.to_sym])).to be_empty
      end

      it "does not accept a params hash in place of a list of hashids" do
        params = ActionController::Parameters.new(hashid: users.first.hashid)

        expect(User.where_hashid(params)).to be_empty
      end

      it "does not load a relation passed in place of a list of hashids" do
        relation = User.all

        expect(User.where_hashid(relation)).to be_empty
        expect(relation).not_to be_loaded
      end
    end

    describe "limits" do
      # Hashids decodes in time quadratic to input length, so over-long strings
      # are rejected before they reach the decoder.
      it "skips hashids longer than the maximum length" do
        too_long = "a" * (described_class::MAX_HASHID_LENGTH + 1)

        expect(User.where_hashid([users.first.hashid, too_long])).to contain_exactly(users.first)
      end

      it "accepts a batch at the maximum size" do
        padded = hashids + ["zzzzzz"] * (described_class::MAX_HASHID_BATCH - hashids.size)

        expect(User.where_hashid(padded)).to match_array(users)
      end

      it "raises rather than silently truncating a batch over the maximum size" do
        oversized = ["zzzzzz"] * (described_class::MAX_HASHID_BATCH + 1)

        expect { User.where_hashid(oversized) }.to raise_error(ArgumentError, /too many hashids/)
      end
    end
  end
end
