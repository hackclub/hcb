# frozen_string_literal: true

require "csv"

module Shared
  class CsvUpload
    class ValidationError < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super("CSV validation failed")
      end

    end

    MAX_FILE_SIZE_BYTES = 1.megabyte

    def initialize(csv_file:)
      @csv_file = csv_file
    end

    def run
      if @csv_file.respond_to?(:size) && @csv_file.size > MAX_FILE_SIZE_BYTES
        raise ValidationError.new(["File is too large. Maximum size is 1 MB."])
      end

      content = @csv_file.read.force_encoding("UTF-8")
      unless content.valid_encoding?
        raise ValidationError.new(["Invalid file: please upload a valid UTF-8 encoded CSV file"])
      end

      # Strip the byte order mark that Excel may add.
      content = content.sub(/\A\uFEFF/, "")
      rows = CSV.parse(content, headers: true, skip_blanks: true)

      if rows.headers.empty? || rows.headers.all?(&:nil?)
        raise ValidationError.new(["CSV file is empty or has no headers"])
      end

      header_mapping = {}
      rows.headers.each do |original|
        next if original.nil?

        header_mapping[original.to_s.strip.downcase] = original
      end

      [rows, header_mapping]
    rescue CSV::MalformedCSVError => e
      raise ValidationError.new(["Invalid CSV format: #{e.message}"])
    end

  end
end
