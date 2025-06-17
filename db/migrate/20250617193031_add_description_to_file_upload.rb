class AddDescriptionToFileUpload < ActiveRecord::Migration[7.1]
  def change
    add_column :file_uploads, :description, :text
  end
end
