# frozen_string_literal: true

module GSuiteService
  class Verify
    G_VERIFY_DOMAIN = "https://gverify.bank.engineering/verify/"
    VALID_MX = "aspmx.l.google.com"
    VALID_SPF = "include:_spf.google.com"
    VALID_SPF_HEADER = "v=spf1"
    VALID_VKEY_HEADER = "google-site-verification="

    def initialize(g_suite_id:)
      @g_suite_id = g_suite_id
    end

    def run
      unless mx_primary_valid? && spf_valid? && verification_key_valid?
        g_suite.mark_verification_error!
      end
    end

    def results(skip_g_verify: false)
      {
        mx_primary: mx_primary_valid?,
        mx_alt1: mx_alt1_valid?,
        mx_alt2: mx_alt2_valid?,
        mx_alt3: mx_alt3_valid?,
        mx_alt4: mx_alt4_valid?,
        spf: spf_valid?,
        verification_key: verification_key_valid?(skip_g_verify:),
        dkim: dkim_valid?,
        dmarc: dmarc_valid?,
      }
    end

    private

    def g_suite
      @g_suite ||= GSuite.find(@g_suite_id)
    end

    def domain
      g_suite.domain
    end

    def mx_primary_valid?
      check_dns Resolv::DNS::Resource::IN::MX do |records|
        return records.map(&:exchange).map(&:to_s).map(&:downcase).include?(VALID_MX)
      end
    end

    (1..4).each do |i|
      domain = "alt#{i}.aspmx.l.google.com"
      define_method "mx_alt#{i}_valid?" do
        check_dns Resolv::DNS::Resource::IN::MX do |records|
          return records.map(&:exchange).map(&:to_s).map(&:downcase).include?(domain)
        end
      end
    end

    def spf_valid?
      check_dns Resolv::DNS::Resource::IN::TXT do |records|
        return records.map(&:data).map(&:downcase).any? do |record|
          record.include?(VALID_SPF_HEADER) && record.include?(VALID_SPF)
        end
      end
    end

    def dkim_valid?
      return nil if g_suite.dkim_key.blank?

      check_dns Resolv::DNS::Resource::IN::TXT do |records|
        return records.map(&:data).any? do |record|
          record.include?(g_suite.dkim_key)
        end
      end
    end

    def dmarc_valid?
      check_dns Resolv::DNS::Resource::IN::TXT do |records|
        return records.map(&:data).any? do |record|
          record.include?("v=DMARC1;")
        end
      end
    end

    def verification_key_valid?(skip_g_verify: false)
      unless skip_g_verify
        res = Faraday.get do |req|
          req.url G_VERIFY_DOMAIN + domain
          req.options.timeout = 60 # it may take heroku up to 30 seconds to cold start
          req.headers["Authorization"] = Rails.application.credentials.g_verify_api_key
        end
        return true if res.success?
      end

      # Some old G Suite domains did not have their verification key generated
      # using G-Verify. This means that G-Verify is unable to successfully
      # check for verification of their domain.
      # As a result, we have a fallback which directly checks the domain's DNS
      # for the verification key.
      check_dns Resolv::DNS::Resource::IN::TXT do |records|
        return records.map(&:data).any? do |record|
          record.match?(/(?i:#{VALID_VKEY_HEADER})#{g_suite.verification_key}/)
        end
      end
    end

    private

    def check_dns(type, &block)
      Resolv::DNS.open do |dns|
        records = dns.getresources(domain, type)
        return block.call(records)
      end
    end

  end
end
