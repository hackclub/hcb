# frozen_string_literal: true

# Reports filesystem inode usage, as a percentage, to AppSignal.
#
# AppSignal's built-in host metrics only cover disk usage in bytes. A
# filesystem can exhaust its inode table while it still has plenty of free
# space, which makes it invisible to the disk_usage metric. This probe reports
# `disk_inode_usage` so it can be alerted on the same way.
#
# Registered as a minutely probe in config/initializers/appsignal_inode_probe.rb.
class DiskInodeUsageProbe
  METRIC_NAME = "disk_inode_usage"

  # -i reports inodes rather than blocks, -P forces the portable one-line-per-
  # filesystem format, and -l limits output to local filesystems so that an
  # unresponsive network mount cannot stall the probe thread.
  DF_COMMAND = "df -iPl"

  def initialize(hostname: Socket.gethostname, df: -> { `#{DF_COMMAND}` })
    @hostname = hostname
    @df = df
  end

  def call
    parse(@df.call).each do |mountpoint, percent|
      Appsignal.set_gauge(METRIC_NAME, percent, hostname: @hostname, mountpoint:)
    end
  end

  private

  def parse(output)
    # Columns are: Filesystem, Inodes, IUsed, IFree, IUse%, Mounted on. The
    # mount point is taken as the rest of the line because it may contain
    # spaces.
    output.to_s.lines.drop(1).filter_map do |line|
      fields = line.split(" ", 6)
      next if fields.length < 6

      # Filesystems that do not track inodes, such as an EFI partition, report
      # "-" here instead of a percentage.
      percent = fields[4][/\A(\d+)%\z/, 1]
      next if percent.nil?

      [fields[5].strip, percent.to_i]
    end
  end

end
