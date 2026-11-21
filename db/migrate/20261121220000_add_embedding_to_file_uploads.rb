# Image embeddings (SigLIP 2, 768 dimensions) for semantic search.
# No index on purpose: an exact scan over this table takes milliseconds at
# this scale and always returns the true nearest matches. Add an HNSW index
# (vector_cosine_ops) once there are hundreds of thousands of rows.
class AddEmbeddingToFileUploads < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    add_column :file_uploads, :embedding, :vector, limit: 768
    # which model produced the embedding, so they can be regenerated if it changes
    add_column :file_uploads, :embedding_model, :string
  end
end
