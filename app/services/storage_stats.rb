require 'open3'

# Storage figures for the system settings page:
# - database size (from PostgreSQL itself)
# - how much the uploaded files take (from Active Storage's blob records)
# - free space on the filesystem that actually holds the uploaded files
class StorageStats
  Uploads = Data.define(:count, :bytes, :expired_count, :expired_bytes, :all_blobs_bytes) do
    # thumbnails/previews are stored as blobs too, but don't belong to an upload
    def generated_bytes = [all_blobs_bytes - bytes, 0].max
  end

  Disk = Data.define(:path, :mount_point, :total_bytes, :used_bytes, :available_bytes, :used_percent)

  def database_bytes
    ActiveRecord::Base.connection.select_value('SELECT pg_database_size(current_database())').to_i
  end

  def uploads
    with_blobs = FileUpload.joins(upload_attachment: :blob)
    expired = with_blobs.where('file_uploads.expires_after < ?', Time.current)
    Uploads.new(
      count: with_blobs.count,
      bytes: with_blobs.sum('active_storage_blobs.byte_size').to_i,
      expired_count: expired.count,
      expired_bytes: expired.sum('active_storage_blobs.byte_size').to_i,
      all_blobs_bytes: ActiveStorage::Blob.sum(:byte_size).to_i
    )
  end

  # Filesystem holding the uploaded files, or nil if it can't be determined.
  # Uses POSIX `df -P` (same output format on Linux and macOS) for one path only;
  # "available" is what a non-root process can still write (excludes reserved blocks).
  def disk(path = storage_root)
    return nil unless path && File.directory?(path)

    output, status = Open3.capture2('df', '-Pk', path.to_s)
    return nil unless status.success?

    parse_df(output, path)
  rescue SystemCallError
    nil
  end

  def storage_root
    service = ActiveStorage::Blob.service
    service.respond_to?(:root) ? service.root : nil
  end

  private

  # Data line: "<filesystem> <1024-blocks> <used> <available> <capacity>% <mounted on>".
  # Matched by its numeric columns, so spaces in the filesystem/mount names are fine.
  DF_LINE = /\s(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+(.+)\z/

  def parse_df(output, path)
    line = output.lines.map(&:chomp).reject(&:empty?).last
    match = line&.match(DF_LINE)
    return nil unless match

    total, used, available, percent = match.captures.first(4).map(&:to_i)
    Disk.new(path: path.to_s, mount_point: match[5], total_bytes: total * 1024, used_bytes: used * 1024,
             available_bytes: available * 1024, used_percent: percent)
  end
end
