require 'rails_helper'

RSpec.describe StorageStats do
  subject(:stats) { described_class.new }

  def df_returns(output, success: true)
    allow(Open3).to receive(:capture2).and_return([output, instance_double(Process::Status, success?: success)])
  end

  describe '#disk' do
    it 'parses Linux df -P output' do
      df_returns(<<~DF)
        Filesystem     1024-blocks     Used Available Capacity Mounted on
        /dev/sda1        157260036 28311040 122525732      19% /rails/storage
      DF

      disk = stats.disk(Dir.pwd)

      expect(disk.total_bytes).to eq 157_260_036 * 1024
      expect(disk.available_bytes).to eq 122_525_732 * 1024
      expect(disk.used_percent).to eq 19
      expect(disk.mount_point).to eq '/rails/storage'
    end

    it 'parses macOS output with spaces in the filesystem and mount names' do
      df_returns(<<~DF)
        Filesystem    1024-blocks      Used Available Capacity  Mounted on
        map auto home    994662584 412345678 582316906      42%    /System/Volumes/Data/home dir
      DF

      disk = stats.disk(Dir.pwd)

      expect(disk.available_bytes).to eq 582_316_906 * 1024
      expect(disk.used_percent).to eq 42
      expect(disk.mount_point).to eq '/System/Volumes/Data/home dir'
    end

    it 'calls df for the given path only, without a shell' do
      df_returns("Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/x 100 50 50 50% /\n")

      stats.disk(Dir.pwd)

      expect(Open3).to have_received(:capture2).with('df', '-Pk', Dir.pwd)
    end

    it 'returns nil when df fails or the output is unexpected' do
      df_returns('', success: false)
      expect(stats.disk(Dir.pwd)).to be_nil

      df_returns("something odd\n")
      expect(stats.disk(Dir.pwd)).to be_nil
    end

    it 'returns nil for a path that does not exist' do
      expect(stats.disk('/does/not/exist')).to be_nil
    end

    it 'reports real figures for the Active Storage directory' do
      disk = stats.disk

      expect(disk.path).to eq ActiveStorage::Blob.service.root.to_s
      expect(disk.total_bytes).to be > 0
      expect(disk.available_bytes).to be_between(0, disk.total_bytes)
    end
  end

  describe '#uploads' do
    it 'sums uploaded files and separates expired ones' do
      active = create(:file_upload)
      expired = create(:file_upload)
      expired.update_columns(expires_after: 1.day.ago)

      uploads = stats.uploads

      size = active.upload.blob.byte_size
      expect(uploads.count).to eq 2
      expect(uploads.bytes).to eq size * 2
      expect(uploads.expired_count).to eq 1
      expect(uploads.expired_bytes).to eq size
    end
  end

  describe '#database_bytes' do
    it 'returns the size of the current database' do
      expect(stats.database_bytes).to be > 1_000_000
    end
  end
end
