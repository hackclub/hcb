# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::FieldSet do
  # Stands in for Jbuilder so these examples test the gating, not the encoder.
  let(:json) do
    Class.new do
      attr_reader :out

      def initialize = @out = {}

      def set!(key, value = nil)
        @out[key] = block_given? ? yield : value
      end
    end.new
  end

  it "emits only the attributes the policy lists" do
    f = described_class.new(json, %i[recipient_name])
    f.recipient_name "Jane Doe"
    f.recipient_email "jane@example.com"

    expect(json.out).to eq(recipient_name: "Jane Doe")
  end

  it "emits nothing when the policy lists nothing" do
    described_class.new(json, []).recipient_name "Jane Doe"

    expect(json.out).to be_empty
  end

  it "does not evaluate the value of a hidden field" do
    evaluated = []

    f = described_class.new(json, %i[shown])
    f.shown  { evaluated << :shown;  "yes" }
    f.hidden { evaluated << :hidden; "no" }

    expect(evaluated).to eq([:shown])
    expect(json.out).to eq(shown: "yes")
  end

  it "skips the block of a hidden nested object" do
    ran = []

    f = described_class.new(json, %i[sender])
    f.nest(:sender)    { ran << :sender }
    f.nest(:recipient) { ran << :recipient }

    expect(ran).to eq([:sender])
  end

  # A malformed call must fail for everyone. If arity were checked after the
  # visibility test, a typo'd serializer would only blow up for the roles that
  # can see the field.
  it "validates the call even when the attribute is hidden" do
    expect { described_class.new(json, []).anything }.to raise_error(ArgumentError)
  end

  it "rejects a value and a block together" do
    expect { described_class.new(json, %i[x]).x("a") { "b" } }.to raise_error(ArgumentError)
  end

  # `public_send` is undefined by the blank slate, so a computed key has to go
  # through `set`. Emitting `"#{key}_id"` references needs exactly this.
  it "emits a computed key through #set" do
    f = described_class.new(json, %i[organization_id user_id])
    f.set(:organization_id, "org_1")
    f.set(:user_id, "usr_1")
    f.set(:hidden_id, "nope")

    expect(json.out).to eq(organization_id: "org_1", user_id: "usr_1")
  end

  it "validates arity on #set too" do
    expect { described_class.new(json, %i[x]).set(:x) }.to raise_error(ArgumentError)
  end

  # Without the blank slate, `f.display "..."` would call Kernel#display and
  # `f.hash "..."` would call Object#hash — quietly, and only for field names
  # that happen to collide with an inherited method.
  it "emits field names that collide with inherited Object methods" do
    f = described_class.new(json, %i[display hash method])
    f.display "a"
    f.hash "b"
    f.method "c"

    expect(json.out).to eq(display: "a", hash: "b", method: "c")
  end

end
