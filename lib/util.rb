# frozen_string_literal: true

module Util
  # converts unixtime to datetime
  #
  # really dumb... but this seems to be the best way to convert unixtime to
  # datetime w/o timezone issues. see https://stackoverflow.com/a/7819254.
  def self.unixtime(unixtime)
    DateTime.strptime(unixtime.to_s, "%s")
  end

  def self.average(array)
    array.sum / array.length
  end

  # provided by https://github.com/maxwofford/heroku-buildpack-sourceversion
  def self.source_version
    file = File.open(".source_version")
    result = file.read.strip
    file.close

    result
  rescue Errno::ENOENT
    return nil
  end

  # also in ApplicationHelper for frontend use
  def self.commit_hash
    @commit_hash ||= begin
      result = ENV["HEROKU_SLUG_COMMIT"]
      result ||= source_version
      result ||= `git show --pretty=%H -q 2> /dev/null`.chomp
    end

    @commit_hash
  end

  def self.commit_dirty?
    @commit_dirty ||= begin
      `git diff --shortstat 2> /dev/null | tail -n1`.chomp.present?
    end
    @commit_dirty
  end
end
