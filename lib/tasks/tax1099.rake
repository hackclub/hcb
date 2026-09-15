# frozen_string_literal: true

namespace :tax1099 do
  # Tax1099 lets whoever runs the export pick its columns, so there is no fixed
  # schema. Confirm the mapping with tax1099:headers before importing, and pass
  # TAX1099_COLUMNS to name any header the aliases don't recognise:
  #
  #   TAX1099_COLUMNS='{"tin":"Tax ID Number","completed_at":"Signed On"}'
  def tax1099_importer(args)
    abort "Pass the path to the Tax1099 export, e.g. rake 'tax1099:import[report.csv]'" if args[:path].blank?

    Tax1099Service::Import.new(
      csv: File.read(args[:path]),
      dry_run: args[:mode] == "dry_run",
      columns: JSON.parse(ENV.fetch("TAX1099_COLUMNS", "{}"))
    )
  end

  desc "Show which column of a Tax1099 export each field reads. Reads headers only, never a row."
  task :headers, [:path] => :environment do |_task, args|
    tax1099_importer(args).column_mapping.each do |field, header|
      puts format("  %-14s %s", field, header || "UNMATCHED")
    end
  end

  desc "Import a Tax1099 W8/W9 report CSV: rake 'tax1099:import[report.csv]', or 'tax1099:import[report.csv,dry_run]' to roll it back"
  task :import, [:path, :mode] => :environment do |_task, args|
    # The export holds raw TINs. Keep it out of the repo and off shared storage,
    # and delete it as soon as the run is done.
    result = tax1099_importer(args).run

    puts "Dry run: nothing was written." if args[:mode] == "dry_run"
    puts "Imported: #{result.imported}"
    puts "Already imported: #{result.skipped}"

    { "Needs manual review" => result.review, "Could not be imported" => result.errors }.each do |heading, lines|
      puts "#{heading}: #{lines.count}"
      lines.each { |line| puts "  #{line}" }
    end
  end
end
