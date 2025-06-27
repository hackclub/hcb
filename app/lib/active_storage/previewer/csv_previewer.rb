# frozen_string_literal: true

require "csv"
require "rmagick"

module ActiveStorage
  module Previewer
    class CSVPreviewer < Previewer
      def self.accept?(blob)
        blob.content_type == "text/csv"
      end

      def preview(**options)
        download_blob_to_tempfile do |file|
          rows = CSV.read(file.path).first(10)
          png = render_table_as_image(rows)
          tempfile = Tempfile.new(["preview", ".png"])
          png.write(tempfile.path)
          yield io: tempfile, filename: "preview.png", content_type: "image/png", **options
        end
      end

      private

      def render_table_as_image(rows)
        include Magick

        cell_width = 150
        cell_height = 40
        rows = rows.map { |row| row.first(5) }
        cols = rows.map(&:size).max
        width = cell_width * cols
        height = cell_height * rows.size

        canvas = Image.new(width, height) { self.background_color = "white" }
        draw = Draw.new
        draw.stroke("black").stroke_width(1).fill_opacity(0)

        rows.each_with_index do |row, y|
          row.each_with_index do |cell, x|
            px = x * cell_width
            py = y * cell_height

            draw.rectangle(px, py, px + cell_width, py + cell_height)

            text = cell.to_s[0...18]

            draw.annotate(canvas, 0, 0, px + 5, py + 25, text) do
              self.fill = "black"
              self.pointsize = 12
              self.gravity = NorthWestGravity
            end
          end
        end

        draw.draw(canvas)
        canvas
      end

    end
  end
end
