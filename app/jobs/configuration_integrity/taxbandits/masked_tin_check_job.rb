# frozen_string_literal: true

module ConfigurationIntegrity
  module Taxbandits
    # Watches a dummy W-9 at TaxBandits, filed with a known fake TIN, so we hear
    # about it if the TIN ever shows up unmasked on the PDFs we serve. Set
    # TAXBANDITS_DUMMY_FORM_ID to that form's PayeeRef (its Tax::Form public ID)
    # and TAXBANDITS_DUMMY_TIN to the TIN it was filed with; without both this
    # does nothing.
    class MaskedTinCheckJob < ApplicationJob
      queue_as :low
      sidekiq_options retry: false

      def perform
        payee_ref = Credentials.fetch(:TAXBANDITS_DUMMY_FORM_ID)
        dummy_tin = Credentials.fetch(:TAXBANDITS_DUMMY_TIN)
        return if payee_ref.blank? || dummy_tin.blank?

        submission = TaxbanditsService.get_submission(payee_ref)
        pdf = Tax::Form.taxbandits_pdf(submission) if submission.present?
        return couldnt_run("TaxBandits has no PDF for the dummy W-9 (PayeeRef #{payee_ref}).") if pdf.nil?

        exposed = begin
          tin_exposed?(pdf, dummy_tin)
        rescue => e
          # Only the class: the message could quote the PDF.
          return couldnt_run("Couldn't read the dummy W-9's PDF (PayeeRef #{payee_ref}) (#{e.class}).")
        end

        ConfigurationIntegrityMailer.with(payee_ref:).taxbandits_leaking_tins.deliver_now if exposed
      end

      private

      def couldnt_run(reason)
        ConfigurationIntegrityMailer.with(check: self.class.name, reason:).check_failed.deliver_now
      end

      # Whether the TIN appears in full in the PDF's rendered text, its form field
      # values, or its raw content streams. Separators are stripped first so
      # "123-45-6789" still matches, and form fields split one per digit are
      # joined back up first (see split_field_values). Raises if the PDF can't be
      # read.
      def tin_exposed?(pdf, tin)
        normalize_for_tin_check(pdf_strings(pdf).join).include?(normalize_for_tin_check(tin))
      end

      def pdf_strings(pdf)
        reader = PDF::Reader.new(StringIO.new(pdf))
        strings = reader.pages.map(&:text)

        reader.objects.each_value do |object|
          collect_pdf_strings(object, strings)
        end

        strings.concat(split_field_values(reader.objects))
      end

      # TaxBandits' W-9 puts the TIN in one form field per digit (txtSSN0 through
      # txtSSN8). Each field's name sits between their values, so the digits never
      # appear in a row. Join every run of fields named <prefix><index> back up,
      # in index order.
      def split_field_values(objects)
        runs = Hash.new { |hash, prefix| hash[prefix] = {} }

        objects.each_value do |object|
          next unless object.is_a?(Hash) && object[:T].is_a?(String)
          next unless (match = decode_pdf_string(object[:T]).match(/\A(.+?)(\d+)\z/))

          value = objects.deref(object[:V])
          runs[match[1]][match[2].to_i] = decode_pdf_string(value) if value.is_a?(String)
        end

        runs.values.map { |run| run.sort.map(&:last).join }
      end

      def collect_pdf_strings(object, strings)
        case object
        when String
          strings << decode_pdf_string(object)
        when Hash
          object.each_value { |value| collect_pdf_strings(value, strings) }
        when Array
          object.each { |value| collect_pdf_strings(value, strings) }
        when PDF::Reader::Stream
          # Cross-reference streams only hold byte offsets, and the PDF spec says
          # they're never encrypted. pdf-reader decrypts them anyway when the PDF
          # is encrypted (TaxBandits' are), which leaves them undecodable.
          return if object.hash[:Type] == :XRef

          collect_pdf_strings(object.hash, strings)
          strings << decode_pdf_string(object.unfiltered_data)
        end
      end

      # PDF strings are either UTF-16BE (with a byte order mark) or a single-byte
      # encoding; either way the digits we're looking for survive as ASCII.
      def decode_pdf_string(string)
        if string.byteslice(0, 2) == "\xFE\xFF".b
          string.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        else
          string.dup.force_encoding(Encoding::BINARY).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        end
      end

      def normalize_for_tin_check(string)
        string.gsub(/[^0-9A-Za-z]/, "").upcase
      end

    end

  end

end
