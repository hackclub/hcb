# frozen_string_literal: true

# AppSignal's host metrics only report disk usage in bytes, so a filesystem
# that runs out of inodes while bytes-free still looks healthy goes unnoticed.
# DiskInodeUsageProbe reports that separately, once a minute per host.
#
# The probe only runs once AppSignal starts its minutely probe thread, so this
# registration is inert in environments where AppSignal is inactive.
Appsignal::Probes.register :disk_inode_usage, -> { DiskInodeUsageProbe.new.call }
