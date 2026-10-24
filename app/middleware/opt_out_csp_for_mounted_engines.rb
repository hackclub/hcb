# frozen_string_literal: true

# The admin tools mounted in `routes.rb` ship their own markup, which we cannot
# nonce: Sidekiq Web sets its own CSP with its own nonce (which secure_headers
# then overwrites), Flipper UI and Maintenance Tasks render bare inline scripts,
# and Blazer, PgHero and Audits1984 ask for a nonce with `nonce: true` — Rails'
# helper, which yields nothing here because HCB's policy comes from
# secure_headers rather than `config.content_security_policy`.
#
# Rather than let the policy break the admin tools, opt their paths out of it.
# Every one of them is already behind AdminConstraint or AuditorConstraint.
class OptOutCspForMountedEngines

  MOUNTED_PATHS = %w[
    /sidekiq
    /maintenance_tasks
    /flipper
    /pghero
    /console
    /blazer
    /letter_opener
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    if mounted_engine?(request.path_info)
      SecureHeaders.opt_out_of_header(request, :csp)
      SecureHeaders.opt_out_of_header(request, :csp_report_only)
    end

    @app.call(env)
  end

  private

  def mounted_engine?(path)
    MOUNTED_PATHS.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
  end

end
