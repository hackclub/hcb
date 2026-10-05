# frozen_string_literal: true

require "rails_helper"

RSpec.describe PublicIdentifiable do
  let!(:users) { create_list(:user, 3) }
  let(:public_ids) { users.map(&:public_id) }

  def user_query_count(&block)
    count = 0
    callback = ->(*, payload) { count += 1 if payload[:sql].include?(%("users")) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    count
  end

  describe ".find_by_public_id" do
    it "returns the record for its own public id" do
      expect(User.find_by_public_id(users.first.public_id)).to eq(users.first)
    end

    it "matches the prefix case insensitively" do
      expect(User.find_by_public_id("USR_#{users.first.hashid}")).to eq(users.first)
    end

    it "returns nil for a hashid prefixed for another model" do
      expect(User.find_by_public_id("org_#{users.first.hashid}")).to be_nil
    end

    it "returns nil for a hashid with no prefix" do
      expect(User.find_by_public_id(users.first.hashid)).to be_nil
    end

    it "returns nil for a public id this model cannot decode" do
      expect(User.find_by_public_id("usr_zzzzzz")).to be_nil
    end

    # `params[:id]` is not always a String: `?id[]=x` yields an Array.
    it "returns nil rather than raising for an id that is not a string" do
      expect(User.find_by_public_id(nil)).to be_nil
      expect(User.find_by_public_id(123)).to be_nil
      expect(User.find_by_public_id([users.first.public_id])).to be_nil
      expect(User.find_by_public_id(ActionController::Parameters.new(id: users.first.public_id))).to be_nil
    end

    # Characterization of long standing behaviour, not an endorsement: the
    # parser takes the first and last underscore separated segments, so anything
    # between them is ignored.
    it "ignores segments between the prefix and the hashid" do
      expect(User.find_by_public_id("usr_junk_#{users.first.hashid}")).to eq(users.first)
    end
  end

  describe ".find_by_public_id!" do
    it "returns the record for its own public id" do
      expect(User.find_by_public_id!(users.first.public_id)).to eq(users.first)
    end

    it "raises RecordNotFound naming the model when nothing matches" do
      expect { User.find_by_public_id!("usr_zzzzzz") }.to raise_error(ActiveRecord::RecordNotFound) do |error|
        expect(error.model).to eq("User")
      end
    end
  end

  describe ".where_public_id" do
    it "returns every record matching the given public ids" do
      expect(User.where_public_id(public_ids)).to match_array(users)
    end

    it "loads the records in a single query" do
      count = user_query_count { User.where_public_id(public_ids).to_a }

      expect(count).to eq(1)
    end

    it "resolves the same records as find_by_public_id" do
      expect(public_ids.filter_map { |id| User.find_by_public_id(id) }).to match_array(User.where_public_id(public_ids))
    end

    it "accepts a single public id" do
      expect(User.where_public_id(users.first.public_id)).to contain_exactly(users.first)
    end

    it "matches the prefix case insensitively" do
      expect(User.where_public_id("USR_#{users.first.hashid}")).to contain_exactly(users.first)
    end

    it "is available on associations" do
      event = create(:event)
      payees = create_list(:payee, 2, event:)
      create(:payee)

      expect(event.payees.where_public_id(payees.map(&:public_id))).to match_array(payees)
    end

    it "keeps the conditions of the relation it is called on" do
      event = create(:event)
      active = create(:payee, event:)
      archived = create(:payee, event:, archived_at: Time.current)

      expect(event.payees.not_archived.where_public_id([active, archived].map(&:public_id))).to contain_exactly(active)
    end

    it "skips a hashid prefixed for another model" do
      # Prefixed for an Event but decodable as a User, so only the prefix check
      # can reject it.
      expect(User.where_public_id([users.first.public_id, "org_#{users.first.hashid}"]))
        .to contain_exactly(users.first)
    end

    it "skips public ids with no prefix" do
      expect(User.where_public_id([users.first.hashid])).to be_empty
    end

    it "skips ids that are not strings" do
      mixed = [nil, 123, [users.first.public_id], users.first.public_id]

      expect(User.where_public_id(mixed)).to contain_exactly(users.first)
    end

    it "returns no records for an empty list" do
      expect(User.where_public_id([])).to be_empty
    end

    it "returns no records for a nil list" do
      expect(User.where_public_id(nil)).to be_empty
    end

    it "returns no records for a params hash" do
      params = ActionController::Parameters.new(id: users.first.public_id)

      expect(User.where_public_id(params)).to be_empty
    end
  end
end
