# frozen_string_literal: true

# Renders the first page of a PDF with libvips.
#
# Active Storage's built-in PDF previewers shell out to `pdftoppm` (Poppler) or
# `mutool` (MuPDF). Neither binary exists on Laravel Cloud's standard image, but
# libvips is installed there with PDF loading support, so we use it instead.

require "active_storage/previewer"

module ActiveStorage
  class Previewer
    class VipsPdfPreviewer < ActiveStorage::Previewer
      DPI = 150

      class << self
        def accept?(blob)
          blob.content_type == "application/pdf" && vips_pdfload_available?
        end

        def vips_pdfload_available?
          return @vips_pdfload_available if defined?(@vips_pdfload_available)

          @vips_pdfload_available = begin
            require "vips"
            ::Vips.type_find("VipsOperation", "pdfload") != 0
          rescue LoadError
            false
          end
        end

      end

      def preview(**options)
        download_blob_to_tempfile do |input|
          image = ::Vips::Image.pdfload(input.path, page: 0, dpi: DPI)
          image = image.flatten(background: 255) if image.has_alpha?

          yield io: StringIO.new(image.write_to_buffer(".png")),
                filename: "#{blob.filename.base}.png",
                content_type: "image/png",
                **options
        end
      end

    end

  end
end
