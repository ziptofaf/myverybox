namespace :embeddings do
  desc "Store image embeddings for uploads that don't have one yet, newest first (semantic search)"
  task backfill: :environment do
    client = ImageEmbeddingClient.new
    scope = FileUpload.where(embedding: nil).includes(upload_attachment: :blob)
    total = scope.count
    done = skipped = 0
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    puts "#{total} uploads without an embedding"

    # newest first: recent uploads are the likeliest search targets
    scope.find_each(order: :desc) do |file_upload|
      blob = file_upload.upload.blob
      if blob && client.embeddable?(blob) && file_upload.store_embedding!(client:)
        done += 1
      else
        skipped += 1
      end
      processed = done + skipped
      if (processed % 100).zero? || processed == total
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        rate = processed / [elapsed, 0.001].max
        puts format("%d/%d processed (%d embedded, %d skipped), %.1f/s", processed, total, done, skipped, rate)
      end
    rescue ActiveStorage::FileNotFoundError
      skipped += 1
    end
    puts "done: #{done} embedded, #{skipped} skipped (not images, missing files or clippy unavailable)"
  end
end
