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

  describe "nondisposable email validation" do
    it "suggests the real domain for a known typo domain" do
      user = build(:user, email: "someone@gmail.con")

      expect(user).to_not be_valid
      expect(user.errors[:email]).to eq(["looks like a typo. Did you mean someone@gmail.com?"])
    end

    it "uses the generic message for a non-typo disposable domain" do
      user = build(:user, email: "someone@tormails.com")

      expect(user).to_not be_valid
      expect(user.errors[:email]).to eq(["provider is unsupported. Please try with another email address."])
    end

    it "suggests gmail.com for googlemail.com, which aliases the same mailbox" do
      user = build(:user, email: "someone@googlemail.com")

      expect(user).to_not be_valid
      expect(user.errors[:email]).to eq(["looks like a typo. Did you mean someone@gmail.com?"])
    end

    it "only blocks disposable domains on create, leaving existing accounts usable" do
      user = create(:user, email: "someone@gmail.com")
      user.update_column(:email, "someone@googlemail.com")

      expect(user.reload).to be_valid
    end

    it "allows major providers and school domains" do
      %w[gmail.com hackclub.com outlook.com icloud.com student.hbuhsd.edu].each do |domain|
        user = build(:user, email: "someone@#{domain}")

        expect(user).to be_valid, "expected #{domain} to be allowed"
      end
    end

    it "allows a provider's regional domains" do
      %w[outlook.de outlook.fr yahoo.fr yahoo.ca hotmail.co.uk].each do |domain|
        user = build(:user, email: "someone@#{domain}")

        expect(user).to be_valid, "expected #{domain} to be allowed"
      end
    end

    it "suggests icloud.com for icloud.co" do
      user = build(:user, email: "someone@icloud.co")

      expect(user).to_not be_valid
      expect(user.errors[:email]).to eq(["looks like a typo. Did you mean someone@icloud.com?"])
    end
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

  describe "name storage" do
    it "keeps full_name in sync with first_name and last_name" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")
      expect(user.full_name).to eq("Fiona Hackworth")

      user.update!(legal_last_name: "Hackworth-Smith")
      expect(user.reload.full_name).to eq("Fiona Hackworth-Smith")
    end

    it "stores a first name on its own" do
      user = create(:user, legal_first_name: "Madonna", legal_last_name: nil)

      expect(user.full_name).to eq("Madonna")
      expect(user.last_name).to be_nil
    end

    it "does not derive a last name from a multi-word first name" do
      user = create(:user, legal_first_name: "Mary Ann", legal_last_name: nil).reload

      expect(user.first_name(legal: true)).to eq("Mary Ann")
      expect(user.last_name(legal: true)).to be_nil
      expect(user.last_name).to be_nil
    end

    it "shows others only the first word when there is no last name" do
      user = create(:user, legal_first_name: "Mary Jane Smith", legal_last_name: nil)

      expect(user.initial_name).to eq("Mary")
    end

    it "initials the surname, not its lowercase particle" do
      user = create(:user, legal_first_name: "Juan", legal_last_name: "de la Cruz")

      expect(user.initial_name).to eq("Juan C")
      expect(user.first_name).to eq("Juan")
    end

    it "does not refill a first name that was just cleared" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")

      expect(user.update(legal_first_name: "")).to be(false)
      expect(user.first_name(legal: true)).to be_nil
    end

    it "returns a nil display first name for a blank new user instead of raising" do
      expect(User.new.first_name).to be_nil
    end

    it "splits a full_name assigned by a legacy writer" do
      user = create(:user, full_name: "Martin Luther King Jr.")

      expect(user.first_name(legal: true)).to eq("Martin Luther")
      expect(user.last_name(legal: true)).to eq("King Jr.")
      expect(user.full_name).to eq("Martin Luther King Jr.")
    end

    it "keeps every word of a full_name holding several people" do
      user = create(:user, full_name: "John and Jane Doe")

      expect(user.reload).to have_attributes(legal_first_name: "John and Jane", legal_last_name: "Doe", full_name: "John and Jane Doe")
    end

    it "serializes the legal name columns, not the preferred name" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth", preferred_name: "FiFi Hacks")

      expect(user.as_json(only: [:legal_first_name, :legal_last_name])).to eq("legal_first_name" => "Fiona", "legal_last_name" => "Hackworth")
    end

    it "canonicalizes a comma-form full_name" do
      user = create(:user, full_name: "Doe, John")

      expect(user.reload).to have_attributes(legal_first_name: "John", legal_last_name: "Doe", full_name: "John Doe")
    end

    it "re-splits when a legacy writer changes full_name" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")

      user.update!(full_name: "Jane Elder")

      expect(user.reload).to have_attributes(legal_first_name: "Jane", legal_last_name: "Elder", full_name: "Jane Elder")
    end

    it "prefers the split names when both are assigned at once" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")

      user.update!(legal_first_name: "Jane", legal_last_name: "Elder", full_name: "Someone Else")

      expect(user.reload).to have_attributes(legal_first_name: "Jane", legal_last_name: "Elder", full_name: "Jane Elder")
    end

    it "trims and collapses whitespace" do
      user = create(:user, legal_first_name: "  Fiona  Rose ", legal_last_name: " Hackworth ")

      expect(user.first_name(legal: true)).to eq("Fiona Rose")
      expect(user.last_name(legal: true)).to eq("Hackworth")
      expect(user.full_name).to eq("Fiona Rose Hackworth")
    end

    it "treats a blank last name as no last name" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "   ")

      expect(user.last_name).to be_nil
      expect(user.full_name).to eq("Fiona")
    end

    it "updates the personal legal entity's name" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")
      expect(user.personal_legal_entity.name).to eq("Fiona Hackworth")

      user.update!(legal_first_name: "Jane", legal_last_name: "Elder")

      expect(user.personal_legal_entity.reload.name).to eq("Jane Elder")
    end

    context "for a row that predates the split columns" do
      let(:user) do
        create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth").tap do |u|
          u.update_columns(legal_first_name: nil, legal_last_name: nil, full_name: "Jane Elder")
          u.reload
        end
      end

      it "derives the names from full_name" do
        expect(user.first_name).to eq("Jane")
        expect(user.last_name).to eq("Elder")
        expect(user.first_name(legal: true)).to eq("Jane")
        expect(user.initial_name).to eq("Jane E")
      end

      it "still allows unrelated updates without touching the name" do
        expect(user.update(phone_number: "+18556254225")).to be(true)
        expect(user.reload.legal_first_name_in_database).to be_nil
        expect(user.full_name).to eq("Jane Elder")
      end

      it "does not allow the name to be removed" do
        user.update(legal_first_name: "", legal_last_name: "")

        expect(user.reload.full_name).to eq("Jane Elder")
        expect(user.first_name(legal: true)).to eq("Jane")
        expect(user.last_name(legal: true)).to eq("Elder")
      end

      it "keeps the surname when only the first name is edited" do
        user.update!(legal_first_name: "Janet")

        expect(user.reload).to have_attributes(legal_first_name: "Janet", legal_last_name: "Elder", full_name: "Janet Elder")
      end

      it "keeps the first name when only the surname is edited" do
        user.update!(legal_last_name: "Smith")

        expect(user.reload).to have_attributes(legal_first_name: "Jane", legal_last_name: "Smith", full_name: "Jane Smith")
      end

      it "does not let a cardholder drop their surname by blanking it" do
        create(:stripe_cardholder, user:)

        user.update(legal_first_name: "Jane", legal_last_name: "")

        expect(user.reload.full_name).to eq("Jane Elder")
        expect(StripeCardholder.last_name(user)).to eq("Elder")
      end

      it "keeps a title in full_name when the parsed name is saved back unchanged" do
        user.update_columns(full_name: "Dr. Juan de la Cruz")

        user.reload.update!(legal_first_name: "Juan", legal_last_name: "de la Cruz", phone_number: "+18556254225")

        expect(user.reload).to have_attributes(legal_first_name: "Juan", legal_last_name: "de la Cruz", full_name: "Dr. Juan de la Cruz")
      end

      it "backfills the columns once the name is edited" do
        user.update!(legal_first_name: "Jane", legal_last_name: "Elder")

        expect(user.reload).to have_attributes(legal_first_name: "Jane", legal_last_name: "Elder", full_name: "Jane Elder")
      end
    end
  end

  describe "name validations" do
    it "allows a user without a name" do
      expect(build(:user, legal_first_name: nil, legal_last_name: nil)).to be_valid
    end

    it "requires a first name when there is a last name" do
      user = build(:user, legal_first_name: nil, legal_last_name: "Hackworth")

      expect(user).not_to be_valid
      expect(user.errors[:legal_first_name]).to include("can't be blank")
    end

    it "does not allow a name to be removed once set" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")

      expect(user.update(legal_first_name: "", legal_last_name: "")).to be(false)
      expect(user.errors[:legal_first_name]).to include("can't be blank")
      expect(user.reload.full_name).to eq("Fiona Hackworth")
    end

    it "does not allow a name to be removed through full_name either" do
      user = create(:user, full_name: "Caleb Denio")

      expect(user.update(full_name: "")).to be(false)
      expect(user.errors[:legal_first_name]).to include("can't be blank")
    end

    it "allows the last name to be removed" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")

      expect(user.update(legal_last_name: "")).to be(true)
      expect(user.reload.full_name).to eq("Fiona")
    end

    it "does not allow a cardholder to remove their last name" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")
      create(:stripe_cardholder, user:)

      expect(user.update(legal_last_name: "")).to be(false)
      expect(user.errors[:legal_last_name]).to include("is required for HCB cards")
      expect(user.reload.full_name).to eq("Fiona Hackworth")
    end

    it "lets a cardholder with no last name on file update other details" do
      user = create(:user, legal_first_name: "Madonna", legal_last_name: nil)
      create(:stripe_cardholder, user:)

      expect(user.reload.update(legal_first_name: "Madonna Louise")).to be(true)
    end

    it "accepts accented letters and name punctuation" do
      user = build(:user, legal_first_name: "María-José", legal_last_name: "O'Brien, Jr.")

      expect(user).to be_valid
    end

    {
      "brackets"    => ["Zach", "Latta [Dev]"],
      "parentheses" => ["Max (test)", "Wofford"],
      "emoji"       => ["Melody ✨", nil],
      "digits"      => ["5512700050241863", nil],
    }.each do |label, (first, last)|
      it "rejects #{label}" do
        user = build(:user, legal_first_name: first, legal_last_name: last)

        expect(user).not_to be_valid
        expect(user.errors[:legal_first_name] + user.errors[:legal_last_name]).to include(User::NAME_CHARACTERS_MESSAGE)
      end
    end

    it "reports invalid characters from a legacy full_name on the split fields" do
      user = build(:user, full_name: "Zach Latta [Dev]")

      expect(user).not_to be_valid
      expect(user.errors[:legal_last_name]).to include(User::NAME_CHARACTERS_MESSAGE)
    end
  end

  describe "#initials" do
    context "when missing name" do
      it "returns initials from email" do
        user = create(:user, email: "user1@example.com", legal_first_name: nil, legal_last_name: nil)

        expect(user.initials).to eql("U")
      end
    end
  end

  describe "#safe_name" do
    it "returns the preferred name when it fits" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth", preferred_name: "FiFi")

      expect(user.safe_name).to eql("FiFi")
    end

    it "falls back to the legal name when the preferred name is too long" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth", preferred_name: "Fiona the Magnificent Hacker")

      expect(user.safe_name).to eql("Fiona Hackworth")
    end

    it "never exceeds 24 chars, even for a long single name" do
      user = create(:user, legal_first_name: "Thisisareallyreallylongsinglename", legal_last_name: nil)

      expect(user.safe_name).to eql("Thisisareallyreallylongs")
    end

    context "when initial name is really long" do
      it "returns safe_name max of 24 chars" do
        user = create(:user, full_name: "Thisisareallyreallylongfirstnamethatembursewillnotlike Last")

        expect(user.safe_name).to eql("Thisisareallyreallylo L")
        expect(user.safe_name.length).to eql(23)
      end
    end
  end

  describe "#first_name and #last_name" do
    it "return the stored names, with only the first word for display" do
      user = create(:user, legal_first_name: "Donald Ervin", legal_last_name: "Knuth")

      expect(user.first_name).to eql("Donald")
      expect(user.last_name).to eql("Knuth")
      expect(user.first_name(legal: true)).to eql("Donald Ervin")
      expect(user.last_name(legal: true)).to eql("Knuth")
    end

    it "return nil for a user without a name, except the display first name" do
      user = create(:user, email: "fiona.h@example.com", legal_first_name: nil, legal_last_name: nil)

      expect(user.first_name).to eq("fiona.h")
      expect(user.last_name).to be_nil
      expect(user.first_name(legal: true)).to be_nil
      expect(user.last_name(legal: true)).to be_nil
    end

    context "with a preferred name" do
      let(:user) { create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth", preferred_name: "FiFi Hacks") }

      it "favor the preferred name" do
        expect(user.first_name).to eql("FiFi")
        expect(user.last_name).to eql("Hacks")
      end

      it "return the legal name when asked" do
        expect(user.first_name(legal: true)).to eql("Fiona")
        expect(user.last_name(legal: true)).to eql("Hackworth")
      end

      it "treat a single-word preferred name as a first name" do
        user.update!(preferred_name: "FiFi")

        expect(user.first_name).to eql("FiFi")
        expect(user.last_name).to be_nil
        expect(user.last_name(legal: true)).to eql("Hackworth")
      end
    end
  end

  describe "#initial_name" do
    it "returns the first name and last initial" do
      user = create(:user, legal_first_name: "First", legal_last_name: "Last")

      expect(user.initial_name).to eql("First L")
    end

    it "uses only the first word of a multi-word first name" do
      user = create(:user, legal_first_name: "Martin Luther", legal_last_name: "King Jr.")

      expect(user.initial_name).to eql("Martin K")
    end

    it "uses the preferred name" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth", preferred_name: "FiFi Hacks")

      expect(user.initial_name).to eql("FiFi H")
    end

    it "returns a single-word preferred name as is" do
      user = create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth", preferred_name: "FiFi")

      expect(user.initial_name).to eql("FiFi")
    end

    it "returns a lone first name as is" do
      user = create(:user, legal_first_name: "Madonna", legal_last_name: nil)

      expect(user.initial_name).to eql("Madonna")
    end

    context "when the user has no name" do
      it "returns the email handle" do
        user = create(:user, email: "user1@example.com", legal_first_name: nil, legal_last_name: nil)

        expect(user.initial_name).to eql("user1")
      end
    end
  end

  describe "onboarding" do
    it "ends once a first name is saved" do
      user = create(:user, legal_first_name: nil, legal_last_name: nil)
      expect(user).to be_onboarding

      user.update!(legal_first_name: "Fiona")

      expect(user).not_to be_onboarding
      expect(user).to be_was_onboarding
    end
  end

  describe "teenager status" do
    let(:first_student_attrs) do
      { name: "first", league: "frc", team_number: "1234", role: "student_leader" }
    end
    let(:first_coach_attrs) do
      { name: "first", league: "frc", team_number: "1234", role: "head_coach" }
    end

    it "marks a user with no birthday but a FIRST student affiliation as a teenager" do
      user = create(:user, affiliations_attributes: [first_student_attrs])

      expect(user).to be_is_teenager
      expect(user.teenager).to be true
      expect(user.joined_as_teenager).to be true
    end

    it "does not mark a FIRST head coach as a teenager" do
      user = create(:user, affiliations_attributes: [first_coach_attrs])

      expect(user).not_to be_is_teenager
      expect(user.teenager).not_to be true
    end

    it "syncs the teenager column when a FIRST student affiliation is added later" do
      user = create(:user)
      expect(user.teenager).not_to be true

      user.update!(affiliations_attributes: [first_student_attrs])

      expect(user.reload.teenager).to be true
      expect(user.joined_as_teenager).to be true
    end

    it "still respects the birthday-based check when there is no FIRST affiliation" do
      user = create(:user, birthday: 16.years.ago)

      expect(user).to be_is_teenager
      expect(user.teenager).to be true
    end

    it "lets birthday take precedence over a FIRST student affiliation when both are present" do
      user = create(:user, birthday: 30.years.ago, affiliations_attributes: [first_student_attrs])

      expect(user).not_to be_is_teenager
      expect(user.teenager).to be false
      expect(user.joined_as_teenager).to be false
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
    let(:application) { Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback") }

    it "locks" do
      user = create(:user, locked_at: nil)
      user.lock!
      expect(user).to be_locked
    end

    it "revokes every API token, including expired ones that still hold a refresh token" do
      user = create(:user)
      live = create(:api_token, user:, application:, use_refresh_token: true)
      expired = create(:api_token, user:, application:, use_refresh_token: true, expires_in: 1, created_at: 3.hours.ago)
      personal = create(:api_token, user:, expires_in: nil)

      user.lock!

      expect([live, expired, personal].each(&:reload)).to all(be_revoked)
    end

    it "revokes outstanding authorization codes and device codes" do
      user = create(:user)
      grant = Doorkeeper::AccessGrant.create!(application:, resource_owner_id: user.id, expires_in: 600, redirect_uri: application.redirect_uri, scopes: "read")
      device_grant = Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.create!(application:, resource_owner_id: user.id, expires_in: 300, scopes: "read")

      user.lock!

      expect(grant.reload).to be_revoked
      expect(Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.exists?(device_grant.id)).to be(false)
    end

    it "freezes every active card and leaves frozen and canceled ones alone" do
      user = create(:user)
      cardholder = create(:stripe_cardholder, user:)
      active_cards = create_list(:stripe_card, 2, :with_stripe_id, stripe_cardholder: cardholder, initially_activated: true)
      frozen_card = create(:stripe_card, :with_stripe_id, stripe_cardholder: cardholder, stripe_status: "inactive", initially_activated: true)
      canceled_card = create(:stripe_card, :with_stripe_id, stripe_cardholder: cardholder, stripe_status: "canceled")
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))

      active_cards.each do |card|
        expect(StripeService::Issuing::Card).to receive(:update).with(card.stripe_id, status: :inactive)
        allow(Stripe::Issuing::Card).to receive(:retrieve).with(id: card.stripe_id).and_return(
          Stripe::Issuing::Card.construct_from(id: card.stripe_id, status: "inactive", brand: "Visa", exp_month: 2, exp_year: 2030, last4: card.last4, type: "virtual", shipping: nil, spending_controls: { spending_limits: [] })
        )
      end

      user.lock!

      expect(active_cards.each(&:reload)).to all(be_frozen)
      expect(active_cards.map(&:last_frozen_by)).to all(eq(User.system_user))
      expect(frozen_card.reload.last_frozen_by).to be_nil
      expect(canceled_card.reload).to be_canceled
    end
  end

  describe "#unlock!" do
    it "unlocks" do
      user = create(:user, locked_at: Time.now)
      user.unlock!
      expect(user).not_to be_locked
    end
  end

  describe "#pretend_is_not_admin" do
    it "is cleared on save for users without an admin role" do
      user = create(:user)
      user.pretend_is_not_admin = true

      user.save!

      expect(user.pretend_is_not_admin).to eq(false)
      expect(user.reload.pretend_is_not_admin).to eq(false)
    end

    it "is kept for auditors and admins" do
      auditor = create(:user, access_level: :auditor, pretend_is_not_admin: true)
      admin = create(:user, :make_admin, pretend_is_not_admin: true)

      expect(auditor.reload.pretend_is_not_admin).to eq(true)
      expect(admin.reload.pretend_is_not_admin).to eq(true)
    end

    it "is cleared when an admin is demoted" do
      admin = create(:user, :make_admin, pretend_is_not_admin: true)

      admin.update!(access_level: :user)

      expect(admin.reload.pretend_is_not_admin).to eq(false)
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

  describe "#update_stripe_cardholder" do
    it "updates phone number on stripe cardholder when phone is verified" do
      user = create(:user, phone_number: "+18556254225", email: "old@example.com")
      cardholder = create(:stripe_cardholder, user:, stripe_phone_number: "0000000000", stripe_email: "old@example.com")
      # Set verified after creation since on_phone_number_update resets it during create
      user.update_column(:phone_number_verified, true)
      user.reload

      expect(StripeService::Issuing::Cardholder).to receive(:update)

      user.update!(email: "new@example.com")
      cardholder.reload

      expect(cardholder.stripe_email).to eq("new@example.com")
      expect(cardholder.stripe_phone_number).to eq("18556254225")
    end

    it "clears phone number on stripe cardholder when phone is not verified" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: true, email: "test@example.com")
      cardholder = create(:stripe_cardholder, user:, stripe_phone_number: "18556254225", stripe_email: "test@example.com")

      expect(StripeService::Issuing::Cardholder).to receive(:update)

      # Changing phone number triggers on_phone_number_update which sets phone_number_verified = false
      user.update!(phone_number: "+12025551234")
      cardholder.reload

      expect(cardholder.stripe_phone_number).to be_nil
    end

    it "does nothing when stripe cardholder has no stripe_id" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: true, email: "test@example.com")
      create(:stripe_cardholder, user:, stripe_id: nil, stripe_email: "test@example.com")

      expect(StripeService::Issuing::Cardholder).not_to receive(:update)

      user.update!(email: "new@example.com")
    end

    it "does nothing when user has no stripe cardholder" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: true)

      expect(StripeService::Issuing::Cardholder).not_to receive(:update)

      user.update!(email: "new@example.com")
    end

    it "triggers when phone_number_verified changes" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: false, email: "test@example.com")
      cardholder = create(:stripe_cardholder, user:, stripe_email: "test@example.com")

      expect(StripeService::Issuing::Cardholder).to receive(:update)

      user.update!(phone_number_verified: true)
      cardholder.reload

      expect(cardholder.stripe_phone_number).to eq("18556254225")
    end

    it "does not send a phone number outside +1/+44 to stripe even when verified" do
      user = create(:user, phone_number: "+919876543210", phone_number_verified: false, email: "test@example.com")
      cardholder = create(:stripe_cardholder, user:, stripe_email: "test@example.com")

      expect(StripeService::Issuing::Cardholder).to receive(:update).with(cardholder.stripe_id, hash_not_including(:phone_number))

      user.update!(phone_number_verified: true)
      cardholder.reload

      expect(cardholder.stripe_phone_number).to be_nil
    end

    it "clears a synced US number once the verified number is no longer on +1/+44" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: false, email: "test@example.com")
      cardholder = create(:stripe_cardholder, user:, stripe_phone_number: "18556254225", stripe_email: "test@example.com")
      user.update_column(:phone_number, "+919876543210")

      expect(StripeService::Issuing::Cardholder).to receive(:update).with(cardholder.stripe_id, hash_including(phone_number: ""))

      user.update!(phone_number_verified: true)
      cardholder.reload

      expect(cardholder.stripe_phone_number).to be_nil
    end
  end

  describe "#phone_number_for_stripe" do
    it "returns the phone number when it is verified and on a supported country code" do
      user = create(:user, phone_number: "+18556254225")
      user.update_column(:phone_number_verified, true)

      expect(user.phone_number_for_stripe).to eq("18556254225")
    end

    it "returns nil when the phone number is not verified" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: false)

      expect(user.phone_number_for_stripe).to be_nil
    end

    it "returns nil when the phone number is outside +1/+44" do
      user = create(:user, phone_number: "+919876543210")
      user.update_column(:phone_number_verified, true)

      expect(user.phone_number_for_stripe).to be_nil
    end

    it "returns nil when there is no phone number" do
      user = create(:user, phone_number: nil, phone_number_verified: true)

      expect(user.phone_number_for_stripe).to be_nil
    end
  end

  describe "#on_phone_number_update" do
    it "resets phone_number_verified when phone number changes" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: true)

      expect(StripeService::Issuing::Cardholder).not_to receive(:update)

      user.update!(phone_number: "+12025551234")

      expect(user.phone_number_verified).to eq(false)
    end
  end

  describe "security configuration change emails" do
    describe "phone_number changes" do
      it "does not send an email when phone_number changes from nil to a value (signup)" do
        user = create(:user, phone_number: nil)

        expect {
          user.update!(phone_number: "+18556254225")
        }.not_to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end

      it "sends an email when phone_number changes from one value to another" do
        user = create(:user, phone_number: "+18556254225")

        expect {
          user.update!(phone_number: "+14155550123")
        }.to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end

      it "does not send an email when phone_number changes from a value to nil" do
        user = create(:user, phone_number: "+18556254225")

        expect {
          user.update!(phone_number: nil)
        }.not_to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end

      it "does not send an email when phone_number is not changed" do
        user = create(:user, phone_number: "+18556254225")

        expect {
          user.update!(full_name: "New Name")
        }.not_to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end
    end

    describe "use_sms_auth changes" do
      it "sends an email when SMS authentication is enabled" do
        user = create(:user, phone_number: "+18556254225", phone_number_verified: true)

        expect {
          user.update!(use_sms_auth: true)
        }.to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end

      it "sends an email when SMS authentication is disabled" do
        user = create(:user, phone_number: "+18556254225", phone_number_verified: true)
        user.update!(use_sms_auth: true)

        expect {
          user.update!(use_sms_auth: false)
        }.to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end

      it "does not send an email when use_sms_auth is not changed" do
        user = create(:user, phone_number: "+18556254225", phone_number_verified: true)
        user.update!(use_sms_auth: true)

        expect {
          user.update!(full_name: "New Name")
        }.not_to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end
    end

    describe "use_two_factor_authentication changes" do
      it "sends an email when two-factor authentication is enabled" do
        user = create(:user, phone_number: "+18556254225", phone_number_verified: true)
        user.update!(use_sms_auth: true)

        expect {
          user.update!(use_two_factor_authentication: true)
        }.to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end

      it "sends an email when two-factor authentication is disabled" do
        user = create(:user, phone_number: "+18556254225", phone_number_verified: true)
        user.update!(use_sms_auth: true)
        user.update!(use_two_factor_authentication: true)

        expect {
          user.update!(use_two_factor_authentication: false)
        }.to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end

      it "does not send an email when use_two_factor_authentication is not changed" do
        user = create(:user, phone_number: "+18556254225", phone_number_verified: true)
        user.update!(use_sms_auth: true)
        user.update!(use_two_factor_authentication: true)

        expect {
          user.update!(full_name: "New Name")
        }.not_to have_enqueued_mail(User::SecurityMailer, :security_configuration_changed)
      end
    end
  end

  describe "payout methods" do
    let(:user) { create(:user) }

    def build_ach
      LegalEntity::PayoutMethod::AchTransfer.new(account_number: "12345678", routing_number: "021000021")
    end

    describe "#personal_legal_entity" do
      it "returns the user's person-type legal entity" do
        expect(user.personal_legal_entity).to be_present
        expect(user.personal_legal_entity).to be_person
      end

      it "returns the person entity, never a business entity the user also belongs to" do
        business = create(:legal_entity, :business)
        user.legal_entity_users.create!(legal_entity: business)

        expect(user.reload.personal_legal_entity).to be_person
        expect(user.personal_legal_entity).not_to eq(business)
      end
    end

    describe "#person_legal_entity_user" do
      it "returns the join row for the person-type legal entity" do
        create(:legal_entity, :business).tap { |b| user.legal_entity_users.create!(legal_entity: b) }

        expect(user.reload.person_legal_entity_user).to eq(
          user.legal_entity_users.find_by(legal_entity: user.personal_legal_entity)
        )
        expect(user.person_legal_entity_user.legal_entity).to be_person
      end
    end

    describe "#default_payout_method" do
      it "is nil when no default payout method exists" do
        expect(user.default_payout_method).to be_nil
        expect(user.default_payout_method&.details).to be_nil
      end

      it "returns the person entity's default payout method and its details" do
        pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)

        expect(user.default_payout_method).to eq(pm)
        expect(user.default_payout_method.details).to eq(pm.details)
        expect(user.default_payout_method.details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
      end
    end
  end

  describe ".search_name" do
    it "finds user by ID" do
      user = create(:user)

      results = User.search_name(user.id.to_s)

      expect(results).to include(user)
    end

    it "returns empty results for non-matching ID" do
      create(:user)

      results = User.search_name("999999999")

      expect(results).to be_empty
    end
  end
end
