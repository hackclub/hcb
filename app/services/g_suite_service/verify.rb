# frozen_string_literal: true

module GSuiteService
  class Verify
    G_VERIFY_DOMAIN = "https://gverify.bank.engineering/verify/"
    VALID_MX = "aspmx.l.google.com"
    VALID_SPF = "include:_spf.google.com"
    VALID_SPF_HEADER = "v=spf1"

    def initialize(g_suite_id:)
      @g_suite_id = g_suite_id
    end

    def run

      unless mx_valid && spf_valid
        g_suite.mark_verification_error!
        return
      end

      res = Faraday.get do |req|
        req.url G_VERIFY_DOMAIN + domain
        req.options.timeout = 60 # it may take heroku up to 30 seconds to cold start
        req.headers["Authorization"] = Rails.application.credentials.g_verify_api_key
      end

      unless res.success? # Since the automatic verification check job runs once every 5 minutes, we just let that run on its own instead of invoking it again here.
        g_suite.mark_verification_error!
      end
    end

    private

    def g_suite
      @g_suite ||= GSuite.find(@g_suite_id)
    end

    def domain
      @domain ||= g_suite.domain
    end

    def mx_valid
      Resolv::DNS.open do |dns|
        mx_records = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
        return mx_records.map(&:exchange).map(&:to_s).map(&:downcase).include?(VALID_MX)
      end
      false
    end

    def spf_valid
      Resolv::DNS.open do |dns|
        txt_records = dns.getresources(domain, Resolv::DNS::Resource::IN::TXT)
        txt_records.each do |record|
          return true if record.data.downcase.include?(VALID_SPF_HEADER) && record.data.downcase.include?(VALID_SPF)
        end
      end
      false
    end

  end
end
