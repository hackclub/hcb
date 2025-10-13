# frozen_string_literal: true

# this is a custom version of https://github.com/basecamp/activestorage-office-previewer
# that also supports CSV files.

require "active_storage/previewer"

module ActiveStorage
  class Previewer
    class DocumentPreviewer < ActiveStorage::Previewer
      ACCEPTABLE_CONTENT_TYPES = [
        "application/msword", # .doc
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document", # .docx

        "application/vnd.ms-powerpoint", # .ppt
        "application/vnd.openxmlformats-officedocument.presentationml.presentation", # .pptx

        "application/vnd.ms-excel", # .xls
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", # .xlsx
        "text/csv", # .csv
      ].freeze

      class << self
        def accept?(blob)
          blob.content_type.in?(ACCEPTABLE_CONTENT_TYPES) && soffice_exists?
        end

        def soffice_exists?
          if @soffice_exists.nil?
            @soffice_exists = system(soffice_path, "--version", out: File::NULL, err: File::NULL)
          else
            @soffice_exists
          end
        end

        def soffice_path
          ActiveStorage.paths[:soffice] || "soffice"
        end

      end

      def preview(**options)
        download_blob_to_tempfile do |input|
          draw_poster_image_from input do |output|
            yield io: output, filename: "#{blob.filename.base}.png", content_type: "image/png", **options
          end
        end
      end

      private

      def draw_poster_image_from(file, &block)
        system soffice_path, "--headless", "--invisible", "--convert-to", "png",
               "--outdir", tmpdir, file.path, out: File::NULL, err: File::NULL
        consume "#{tmpdir}/#{File.basename(file.path, ".*")}.png", &block
      end

      def consume(path, &block)
        File.open(path, "rb", &block)
      ensure
        File.delete(path)
      end

      def soffice_path
        self.class.soffice_path
      end

    end

  end
end
