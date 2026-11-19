# frozen_string_literal: true

require "rails_helper"

# RSpec, and the `find spec -name '*_spec.rb'` CI uses to shard, only pick up
# files ending in `_spec.rb`. A spec saved under any other name is silently
# skipped, so it can rot without anyone noticing.
RSpec.describe "Spec file naming" do
  it "names every spec file *_spec.rb so RSpec runs it" do
    non_spec_files = %w[
      spec/spec_helper.rb
      spec/rails_helper.rb
      spec/support/**/*.rb
      spec/factories/**/*.rb
      spec/mailers/previews/**/*.rb
    ]
    all_files = Dir.glob("spec/**/*.rb", base: Rails.root)
    spec_files = Dir.glob("spec/**/*_spec.rb", base: Rails.root)

    misnamed = all_files - spec_files - Dir.glob(non_spec_files, base: Rails.root)

    expect(misnamed).to be_empty, "RSpec never runs these files. Rename them to end in _spec.rb:\n#{misnamed.join("\n")}"
  end
end
