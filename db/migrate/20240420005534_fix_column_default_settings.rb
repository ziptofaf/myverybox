class FixColumnDefaultSettings < ActiveRecord::Migration[7.1]
  def change
    change_column_null :file_uploads, :url, false
    change_column_null :api_keys, :active, false, true
    change_column_null :api_keys, :value, false
    change_column_default :api_keys, :active, true
  end
end
