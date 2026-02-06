# frozen_string_literal: true

require "rails_helper"

RSpec.describe PublicIdentifiable do
  describe "MODELS registry" do
    it "includes all models with PublicIdentifiable" do
      # Eager load all models to ensure we catch everything
      Rails.application.eager_load!

      # Find all models that include PublicIdentifiable
      # Exclude STI children that share the same prefix as their parent
      # Use ActiveRecord::Base.descendants to include gem models like PublicActivity::Activity
      all_models_with_public_id = ActiveRecord::Base.descendants
        .select { |model| model.respond_to?(:get_public_id_prefix) }
        .reject do |model|
          model.superclass.respond_to?(:get_public_id_prefix) &&
            model.get_public_id_prefix == model.superclass.get_public_id_prefix
        end

      registered_models = described_class.models.values.to_set
      actual_models = all_models_with_public_id.to_set

      missing_models = actual_models - registered_models
      extra_models = registered_models - actual_models

      expect(missing_models.map(&:name)).to be_empty,
        "MODELS registry is missing: #{missing_models.map { |m| "#{m.name} (prefix: #{m.get_public_id_prefix})" }.join(", ")}"

      expect(extra_models.map(&:name)).to be_empty,
        "MODELS registry has extra models that don't have PublicIdentifiable: #{extra_models.map(&:name).join(", ")}"
    end

    it "has keys that match model prefixes" do
      # Verify that each model's prefix matches its key in the registry
      described_class.models.each do |prefix, model_class|
        expect(model_class.get_public_id_prefix).to eq(prefix.to_s),
          "#{model_class.name} has prefix '#{model_class.get_public_id_prefix}' but is registered under '#{prefix}'"
      end
    end

    it "enforces prefix format (lowercase a-z only)" do
      described_class.models.each_key do |prefix|
        expect(prefix.to_s).to match(/\A[a-z]+\z/),
          "Prefix '#{prefix}' must be lowercase and only contain letters a-z"
      end
    end

    it "enforces prefix length (exactly 3 characters)" do
      described_class.models.each_key do |prefix|
        expect(prefix.to_s.length).to eq(3),
          "Prefix '#{prefix}' must be exactly 3 characters long (current length: #{prefix.to_s.length})"
      end
    end
  end

  describe ".parse_components" do
    it "parses valid public ID format" do
      result = described_class.parse_components("usr_abc123")

      expect(result).to eq({ prefix: :usr, hashid: "abc123" })
    end

    it "handles multiple underscores by treating everything after first underscore as hashid" do
      result = described_class.parse_components("usr_abc_123_xyz")

      expect(result).to eq({ prefix: :usr, hashid: "abc_123_xyz" })
    end

    it "downcases prefix" do
      result = described_class.parse_components("USR_abc123")

      expect(result).to eq({ prefix: :usr, hashid: "abc123" })
    end

    it "returns nil for string without underscore" do
      result = described_class.parse_components("usrabc123")

      expect(result).to be_nil
    end

    it "returns nil for empty string" do
      result = described_class.parse_components("")

      expect(result).to be_nil
    end

    it "returns nil for non-string input" do
      expect(described_class.parse_components(nil)).to be_nil
      expect(described_class.parse_components(123)).to be_nil
      expect(described_class.parse_components([])).to be_nil
    end

    it "returns nil for string with only underscore" do
      result = described_class.parse_components("_")

      expect(result).to be_nil
    end

    it "returns nil for string ending with underscore (no hashid)" do
      result = described_class.parse_components("usr_")

      expect(result).to be_nil
    end

    it "returns nil for string starting with underscore (no prefix)" do
      result = described_class.parse_components("_abc123")

      expect(result).to be_nil
    end
  end

  describe ".find_by_public_id" do
    let(:user) { create(:user) }

    it "returns record with valid public ID" do
      result = described_class.find_by_public_id(user.public_id)

      expect(result).to eq(user)
    end

    it "returns nil with invalid format" do
      result = described_class.find_by_public_id("invalid")

      expect(result).to be_nil
    end

    it "returns nil with unknown prefix" do
      result = described_class.find_by_public_id("xyz_abc123")

      expect(result).to be_nil
    end

    it "returns nil with non-existent record" do
      result = described_class.find_by_public_id("usr_nonexistent999")

      expect(result).to be_nil
    end
  end

  describe "auto-configuration" do
    it "sets prefix from MODELS registry when model is loaded" do
      # Verify that models have their prefix set automatically
      described_class.models.each do |prefix, model_class|
        expect(model_class.public_id_prefix).to eq(prefix.to_s),
          "#{model_class.name} should have prefix '#{prefix}' auto-configured"
      end
    end
  end

  describe "ClassMethods" do
    let(:user) { create(:user) }

    describe ".find_by_public_id" do
      it "finds record by its own public ID" do
        result = User.find_by_public_id(user.public_id)

        expect(result).to eq(user)
      end

      it "returns nil when prefix doesn't match model" do
        # Try to find a user with an org prefix
        result = User.find_by_public_id("org_abc123")

        expect(result).to be_nil
      end

      it "returns nil for invalid format" do
        result = User.find_by_public_id("invalid")

        expect(result).to be_nil
      end
    end

    describe ".find_by_public_id!" do
      it "finds record by its public ID" do
        result = User.find_by_public_id!(user.public_id)

        expect(result).to eq(user)
      end

      it "raises ActiveRecord::RecordNotFound when record not found" do
        expect {
          User.find_by_public_id!("usr_nonexistent999")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "raises ActiveRecord::RecordNotFound for invalid format" do
        expect {
          User.find_by_public_id!("invalid")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe ".get_public_id_prefix" do
      it "returns the configured prefix" do
        expect(User.get_public_id_prefix).to eq("usr")
      end
    end
  end
end
