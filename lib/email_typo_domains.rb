# frozen_string_literal: true

# Single source of truth for the "unambiguous typo of, or alias for, a major
# provider" domains blocked in config/initializers/nondisposable.rb. Grouped by
# the real domain so a new typo is one line to add; TYPO_TO_REAL is derived
# once at load for O(1) lookup from User's validation message.
#
# googlemail.com is the alias case: it's a real Google domain that delivers to
# the same mailbox as gmail.com, so signing up with it mints a second account
# for an inbox we already have. Suggesting the gmail.com form costs those users
# nothing, since it reaches the same place.
module EmailTypoDomains
  REAL_TO_TYPOS = {
    "gmail.com"      => %w[
      gmail.con gmail.co gamil.com gmail.ocm gmail.ckm gmail.cok gmail.xom
      gmali.com gamail.com gmail.cpom gmail.cokm gmail.fom gmil.com
      gmail.cm gmail.om gmai.com gnail.com
      googlemail.com
    ],
    "icloud.com"     => %w[icloud.con],
    "hackclub.com"   => %w[hackclub.co hackclub.con],
    "outlook.com"    => %w[outlook.con],
    "protonmail.com" => %w[protonmail.con],
  }.freeze

  TYPO_TO_REAL = REAL_TO_TYPOS.each_with_object({}) { |(real, typos), h| typos.each { |typo| h[typo] = real } }.freeze

  ALL = TYPO_TO_REAL.keys.freeze

  def self.suggestion_for(email)
    TYPO_TO_REAL[email.to_s.split("@").last&.strip&.downcase]
  end
end
