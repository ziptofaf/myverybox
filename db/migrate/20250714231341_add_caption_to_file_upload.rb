class AddCaptionToFileUpload < ActiveRecord::Migration[7.1]
  def change
    add_column :file_uploads, :caption, :text, null: true
  end
end
