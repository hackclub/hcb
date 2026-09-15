# frozen_string_literal: true

namespace :tax1099 do
  desc "Import a Tax1099 W8/W9 report CSV: rake 'tax1099:import[report.csv]', or 'tax1099:import[report.csv,dry_run]' to roll it back"
  task :import, [:path, :mode] => :environment do |_task, args|
    abort "Pass the path to the Tax1099 export, e.g. rake 'tax1099:import[report.csv]'" if args[:path].blank?

    # The export holds raw TINs. Keep it out of the repo and off shared storage,
    # and delete it as soon as the run is done.
    result = Tax1099Service::Import.new(csv: File.read(args[:path]), dry_run: args[:mode] == "dry_run").run

    puts "Dry run: nothing was written." if args[:mode] == "dry_run"
    puts "Imported: #{result.imported}"
    puts "Already imported: #{result.skipped}"

    { "Needs manual review" => result.review, "Could not be imported" => result.errors }.each do |heading, lines|
      puts "#{heading}: #{lines.count}"
      lines.each { |line| puts "  #{line}" }
    end
  end
end
