# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiskInodeUsageProbe do
  # Format of `df -iPl` on the production hosts.
  let(:df_output) do
    <<~DF
      Filesystem      Inodes   IUsed  IFree IUse% Mounted on
      tmpfs           992153     755 991398    1% /run
      /dev/sda1      2427136 2427134      2  100% /
      /dev/sda15           0       0      0     - /boot/efi
    DF
  end

  def probe(output, hostname: "server-jobs-1")
    described_class.new(hostname:, df: -> { output })
  end

  before do
    allow(Appsignal).to receive(:set_gauge)
  end

  it "reports the inode percentage tagged with the host and mount point" do
    probe(df_output).call

    expect(Appsignal).to have_received(:set_gauge)
      .with("disk_inode_usage", 1, { hostname: "server-jobs-1", mountpoint: "/run" })
  end

  it "reports 100 percent for a filesystem whose inode table is exhausted" do
    probe(df_output).call

    expect(Appsignal).to have_received(:set_gauge)
      .with("disk_inode_usage", 100, { hostname: "server-jobs-1", mountpoint: "/" })
  end

  it "skips filesystems that do not track inodes" do
    probe(df_output).call

    expect(Appsignal).not_to have_received(:set_gauge)
      .with(anything, anything, hash_including(mountpoint: "/boot/efi"))
  end

  it "keeps mount points that contain spaces intact" do
    output = <<~DF
      Filesystem      Inodes   IUsed  IFree IUse% Mounted on
      /dev/sdb1       100000    5000  95000    5% /mnt/my backup
    DF

    probe(output).call

    expect(Appsignal).to have_received(:set_gauge)
      .with("disk_inode_usage", 5, { hostname: "server-jobs-1", mountpoint: "/mnt/my backup" })
  end

  it "reports nothing when df returns no filesystems" do
    probe("").call

    expect(Appsignal).not_to have_received(:set_gauge)
  end
end
