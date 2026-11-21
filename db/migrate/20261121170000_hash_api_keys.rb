# API keys are now shown only once, at creation, and stored as a SHA-256
# digest. Existing keys keep working: their plaintext value is hashed here
# (sha256 of the UTF-8 string, hex encoded - same as ApiKey.digest) and then
# dropped, which is why this migration cannot be reversed.
class HashApiKeys < ActiveRecord::Migration[8.1]
  def up
    add_column :api_keys, :value_digest, :string
    add_column :api_keys, :description, :string
    add_column :api_keys, :expires_at, :datetime
    add_column :api_keys, :last_used_at, :datetime

    execute <<~SQL
      UPDATE api_keys SET value_digest = encode(sha256(convert_to(value, 'UTF8')), 'hex')
    SQL

    change_column_null :api_keys, :value_digest, false
    add_index :api_keys, :value_digest, unique: true
    remove_column :api_keys, :value
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "plaintext API key values were discarded"
  end
end
