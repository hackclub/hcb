require "csv"
require "chunky_png"

module ActiveStorage
  class Previewer::CSVPreviewer < Previewer
    def self.accept?(blob)
      blob.content_type == "text/csv"
    end

    def preview(**options)
      download_blob_to_tempfile do |file|
        rows = CSV.read(file.path).first(5)

        png = render_table_as_image(rows)
        tempfile = Tempfile.new(["preview", ".png"])
        png.save(tempfile.path)

        yield io: tempfile, filename: "preview.png", content_type: "image/png", **options
      end
    end

    private

    def render_table_as_image(rows)
      require "chunky_png"

      cell_width = 150
      cell_height = 40
      cols = rows.map(&:size).max
      width = cell_width * cols
      height = cell_height * rows.size

      png = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)

      rows.each_with_index do |row, y|
        row.each_with_index do |cell, x|
          px = x * cell_width
          py = y * cell_height

          png.rect(px, py, px + cell_width, py + cell_height, ChunkyPNG::Color::BLACK, ChunkyPNG::Color::WHITE)
        end
      end

      png
    end
  end
end
