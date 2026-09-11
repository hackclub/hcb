# frozen_string_literal: true

require "rails_helper"

# `visible_attributes` is called from outside the policy — the v5 serializers
# reach it through `policy(record).visible_attributes`. A policy that defines
# it below `private` therefore raises NoMethodError at render time rather than
# failing anywhere near the definition, and only for the objects that policy
# serializes. Five policies had exactly that bug at once, so it is guarded here
# rather than left to review.
RSpec.describe "policy visible_attributes contract" do
  # Loading every policy file is what makes `subclasses` complete; in the test
  # environment they are otherwise autoloaded lazily.
  before(:all) do
    Dir[Rails.root.join("app/policies/**/*.rb")].each { |f| require f }
  end

  def policies_defining(method)
    ApplicationPolicy.subclasses.flat_map { |k| [k, *k.subclasses] }.uniq.select do |klass|
      klass.instance_methods(false).include?(method) || klass.private_instance_methods(false).include?(method)
    end
  end

  it "defines visible_attributes publicly wherever it is defined" do
    offenders = policies_defining(:visible_attributes).reject do |klass|
      klass.public_method_defined?(:visible_attributes)
    end

    expect(offenders).to be_empty,
                         "these policies define visible_attributes under `private`, so the " \
                         "serializer cannot call it: #{offenders.map(&:name).join(', ')}"
  end

  it "defines policy_event publicly wherever it is overridden" do
    offenders = policies_defining(:policy_event).reject do |klass|
      klass.public_method_defined?(:policy_event)
    end

    expect(offenders).to be_empty,
                         "these policies define policy_event under `private`: #{offenders.map(&:name).join(', ')}"
  end

  # Every list must be an array of symbols — a stray string would silently never
  # match a serializer key, which is a missing-field bug rather than a leak, but
  # still a bug.
  it "returns symbols from the ApplicationPolicy default" do
    expect(ApplicationPolicy.new(nil, nil).visible_attributes).to eq([])
  end

end
