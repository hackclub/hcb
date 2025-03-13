# frozen_string_literal: true

module GSuiteService
  class GetVerificationKey
    G_VERIFY_DOMAIN = "https://gverify.bank.engineering"

    def initialize(g_suite_id:)
      @g_suite_id = g_suite_id
    end

    def run
      res = Faraday.get do |req|
        req.url url
        req.options.timeout = 60 # it may take heroku up to 30 seconds to cold start
        req.headers["Authorization"] = Credentials.fetch(:GVERIFY)
      end

      unless res.success?
        raise ArgumentError, "Failed to get Google Workspace Verification Key for #{domain}"
      end

      JSON.parse(res.body)["token"] # contains the verification key
    end

    private

    def g_suite
      GSuite.find(@g_suite_id)
    end

    def domain
      g_suite.domain
    end

    def url
      "#{G_VERIFY_DOMAIN}/token/#{domain}"
    end

  end
end
