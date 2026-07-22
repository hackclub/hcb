# frozen_string_literal: true

# Single source of truth for the "unambiguous typo of a major provider"
# domains blocked in config/initializers/nondisposable.rb. Grouped by the
# real domain so a new typo is one line to add; TYPO_TO_REAL is derived
# once at load for O(1) lookup from User's validation message.
module EmailTypoDomains
  REAL_TO_TYPOS = {
    "gmail.com"      => %w[
      gmail.con gmail.co gamil.com gmail.ocm gmail.ckm gmail.cok gmail.xom
      gmali.com gamail.com gmail.cpom gmail.cokm gmail.fom gmil.com
    ],
    "icloud.com"     => %w[icloud.con],
    "hackclub.com"   => %w[hackclub.co],
    "protonmail.com" => %w[protonmail.con],
  }.freeze

  TYPO_TO_REAL = REAL_TO_TYPOS.each_with_object({}) { |(real, typos), h| typos.each { |typo| h[typo] = real } }.freeze

  ALL = TYPO_TO_REAL.keys.freeze

  def self.suggestion_for(email)
    TYPO_TO_REAL[email.to_s.split("@").last]
  end
end
