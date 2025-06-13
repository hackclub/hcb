require "imgkit"

module ActiveStorage
  class Previewer::CSVPreviewer < Previewer
    def self.accept?(blob)
      blob.content_type == "text/csv"
    end

    def preview(**options)
      download_blob_to_tempfile do |file|
        rows = CSV.read(file.path).first(10)

        html = render_html_table(rows)

        kit = IMGKit.new(html, quality: 100, width: 1000, height: 500)
        image_path = Tempfile.new(["preview", ".png"])
        kit.to_file(image_path.path)

        original_name = blob.filename.base
        filename = "#{original_name}_preview.png"

        yield io: File.open(image_path.path), filename: filename, content_type: "image/png", **options
      end
    end

    private

    def render_html_table(rows)
      headers = rows.first
      body_rows = rows[1..]

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: sans-serif; padding: 20px; }
            table {
              border-collapse: collapse;
              width: 100%;
              font-size: 14px;
              table-layout: fixed;
            }
            th, td {
              border: 1px solid #ccc;
              padding: 8px;
              text-align: left;
              overflow: hidden;
              text-overflow: ellipsis;
              white-space: nowrap;
            }
            th {
              background-color: #f5f5f5;
            }
            tr:nth-child(even) {
              background-color: #fafafa;
            }
          </style>
        </head>
        <body>
          <table>
            <thead>
              <tr>#{headers.map { |h| "<th>#{h}</th>" }.join}</tr>
            </thead>
            <tbody>
              #{body_rows.map { |row| "<tr>#{row.map { |cell| "<td>#{cell}</td>" }.join}</tr>" }.join}
            </tbody>
          </table>
        </body>
        </html>
      HTML
    end
  end
end
