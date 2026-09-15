# frozen_string_literal: true

require "rails_helper"

# config/schedule.yml is loaded by config/initializers/sidekiq.rb into
# sidekiq-cron, which resolves each entry's `class` by name at enqueue time. A
# typo there fails silently in production — the cron entry simply never runs —
# so verify every scheduled class actually exists.
RSpec.describe "config/schedule.yml" do
  let(:schedule) { YAML.load_file(Rails.root.join("config/schedule.yml")) }

  it "schedules only job classes that exist" do
    missing = schedule.filter_map do |name, entry|
      klass = entry["class"]
      name unless klass.safe_constantize
    end

    expect(missing).to be_empty, "these schedule.yml entries name a class that doesn't exist: #{missing.join(", ")}"
  end

  it "schedules only ActiveJob or Sidekiq workers" do
    invalid = schedule.filter_map do |name, entry|
      klass = entry["class"].safe_constantize
      next if klass.nil?

      name unless klass <= ActiveJob::Base || klass.include?(Sidekiq::Job)
    end

    expect(invalid).to be_empty, "these schedule.yml entries name a class that isn't a job: #{invalid.join(", ")}"
  end
end
