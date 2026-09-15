# frozen_string_literal: true

InvisibleCaptcha.setup do |config|
  # config.honeypots           << ['more', 'fake', 'attribute', 'names']
  config.visual_honeypots    = false

  # The timestamp feature does two things: it rejects submissions when the form
  # was never rendered (the view helper writes a token into the session), and it
  # rejects submissions that arrive faster than `timestamp_threshold`.
  #
  # Only the first is wanted. It costs a real browser nothing and rejects
  # scripts that POST straight at an endpoint, whereas the speed check is easy
  # for a script to defeat by waiting and would reject people whose password
  # manager autofills the form and who then submit right away. A threshold of 0
  # keeps the "was the form actually rendered" check and disables the speed
  # check, since submitting always takes a positive amount of time.
  #
  # The view helper consults this global flag rather than any per-action option,
  # so it has to be enabled here for the token to be written at all. Controllers
  # that have not been checked for multi-step flows opt out with
  # `timestamp_enabled: false`; see LoginsController for why that matters.
  config.timestamp_threshold = 0
  config.timestamp_enabled   = true
  # config.injectable_styles   = false
  config.spinner_enabled     = false

  # Leave these unset if you want to use I18n (see below)
  config.sentence_for_humans = "please do not spam us. we are trying to do good."
  # config.timestamp_error_message = 'Sorry, that was too quick! Please resubmit.'
end
