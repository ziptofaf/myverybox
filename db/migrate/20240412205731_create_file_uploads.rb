class CreateFileUploads < ActiveRecord::Migration[7.1]
  def change
    create_table :file_uploads do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.datetime :expires_after
      t.string :url

      t.timestamps
    end
    add_index :file_uploads, :url, unique: true
  end
end
