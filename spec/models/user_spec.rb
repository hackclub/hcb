# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid" do
    user = create(:user)

    expect(user).to be_valid
  end

  it "is admin" do
    user = create(:user, access_level: :admin)

    expect(user).to be_admin
  end

  context "birthday validations" do
    it "fails validation when birthday is removed" do
      user = create(:user, full_name: "Caleb Denio")
      expect(user).to be_valid

      user.update(birthday: 13.years.ago)
      expect(user).to be_valid

      user.update(birthday: nil)
      expect(user).to_not be_valid
    end

    it "can change it from nil when it's valid" do
      user = create(:user)
      dob = 13.years.ago

      user.update(birthday: dob)
      expect(user).to be_valid
    end

    it "can still update other attributes if it's nil" do
      user = create(:user, full_name: "Turing, Alan")

      user.update(full_name: "Turing Alan")
      expect(user).to be_valid
    end
  end

  context "when full_name is removed" do
    it "fails validation" do
      user = create(:user, full_name: "Caleb Denio")
      expect(user.full_name).to eq("Caleb Denio")

      user.update(full_name: "")
      expect(user).to_not be_valid
    end
  end

  describe "#initials" do
    context "when missing name" do
      it "returns initials from email" do
        user = create(:user, email: "user1@example.com", full_name: nil)

        expect(user.initials).to eql("U")
      end
    end
  end

  describe "#safe_name" do
    context "when initial name is really long" do
      it "returns safe_name max of 24 chars" do
        user = create(:user, full_name: "Thisisareallyreallylongfirstnamethatembursewillnotlike Last")

        expect(user.safe_name).to eql("Thisisareallyreallylo L")
        expect(user.safe_name.length).to eql(23)
      end
    end
  end

  describe "#first_name" do
    context "when name is downcased" do
      it "returns" do
        user = create(:user, full_name: "ann marie")

        expect(user.first_name).to eql("ann")
      end
    end

    context "when multiple first names" do
      it "returns actual first name" do
        user = create(:user, full_name: "Prof. Donald Ervin Knuth")

        expect(user.first_name).to eql("Donald")
      end
    end

    context "when name entered with comma" do
      it "returns actual first name" do
        user = create(:user, full_name: "Turing, Alan M.")

        expect(user.first_name).to eql("Alan")
      end
    end
  end

  describe "#last_name" do
    it "returns actual last name" do
      user = create(:user, full_name: "Ken Griffey Jr.")

      expect(user.last_name).to eql("Griffey")
    end

    context "when name is downcased" do
      it "returns" do
        user = create(:user, full_name: "ann marie")

        expect(user.last_name).to eql("marie")
      end
    end

    context "when entered with comma" do
      it "returns actual last name" do
        user = create(:user, full_name: "Carreño Quiñones, María-Jose")

        expect(user.last_name).to eql("Quiñones")
      end
    end
  end

  describe "#initial_name" do
    it "returns" do
      user = create(:user, full_name: "First Last")

      expect(user.initial_name).to eql("First L")
    end

    context "when first name is missing" do
      it "is invalid" do
        user = build(:user, full_name: "Last")

        expect(user).not_to be_valid
        expect(user.errors[:full_name]).not_to be_empty
      end
    end

    context "when last name is missing" do
      it "is invalid" do
        user = build(:user, full_name: "First")

        expect(user).not_to be_valid
        expect(user.errors[:full_name]).not_to be_empty
      end
    end

    context "when full_name is nil" do
      it "returns" do
        user = create(:user, email: "user1@example.com", full_name: nil)

        expect(user.initial_name).to eql("user1")
      end
    end
  end

  describe "#locked?" do
    context "when locked" do
      it "returns" do
        user = create(:user, locked_at: Time.now)
        expect(user).to be_locked
      end
    end

    context "when unlocked" do
      it "returns" do
        user = create(:user, locked_at: nil)
        expect(user).not_to be_locked
      end
    end
  end

  describe "#lock!" do
    it "locks" do
      user = create(:user, locked_at: nil)
      user.lock!
      expect(user).to be_locked
    end
  end

  describe "#unlock!" do
    it "unlocks" do
      user = create(:user, locked_at: Time.now)
      user.unlock!
      expect(user).not_to be_locked
    end
  end

  describe "#private" do
    describe "#namae" do
      context "when brackets in name" do
        it "can't parse the name" do
          user = build(:user, full_name: "Zach Latta [Dev]")

          expect(user).not_to be_valid
          expect(user.errors[:full_name]).not_to be_empty
        end
      end

      context "when parentheses" do
        it "can't parse the name" do
          user = build(:user, full_name: "Max (test) Wofford")

          expect(user).not_to be_valid
          expect(user.errors[:full_name]).not_to be_empty
        end
      end

      context "when emojis in name" do
        it "can't parse the name" do
          user = build(:user, full_name: "Melody ✨")

          expect(user).not_to be_valid
          expect(user.errors[:full_name]).not_to be_empty
        end
      end

      context "when a number" do
        it "can't parse the name" do
          user = build(:user, full_name: "5512700050241863")

          expect(user).not_to be_valid
          expect(user.errors[:full_name]).not_to be_empty
        end
      end
    end
  end

  describe "#use_two_factor_authentication" do
    it "cannot be disabled by admins" do
      user = create(:user, :make_admin, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)

      expect(user.update(use_two_factor_authentication: false)).to eq(false)
      expect(user.errors[:use_two_factor_authentication]).to contain_exactly("cannot be disabled for admin accounts")
    end

    it "cannot be disabled by admins pretending not to be admins" do
      user = create(:user, :make_admin, use_two_factor_authentication: true, pretend_is_not_admin: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)

      expect(user.update(use_two_factor_authentication: false)).to eq(false)
      expect(user.errors[:use_two_factor_authentication]).to contain_exactly("cannot be disabled for admin accounts")
    end

    it "can be disabled by regular users" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)

      expect(user.update(use_two_factor_authentication: false)).to eq(true)
    end

    it "can be enabled with SMS auth" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: true)
      user.update!(use_sms_auth: true)

      expect(user.use_sms_auth).to eq(true)
      expect(user.update(use_two_factor_authentication: true)).to eq(true)
    end

    it "cannot be enabled without any second factor" do
      user = create(:user)

      expect(user.update(use_two_factor_authentication: true)).to eq(false)
      expect(user.errors[:use_two_factor_authentication]).to contain_exactly("can not be enabled without a second authentication factor")
    end
  end
end
