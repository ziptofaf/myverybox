class AddImageDescriptionAnalysisSetting < ActiveRecord::Migration[7.1]
  def up
    time_now = Time.now.iso8601
    execute "INSERT INTO settings (name, value_type, value, created_at, updated_at) values ('image_description_analysis', 'bool', '0', '#{time_now}', '#{time_now}')"
  end

  def down
    execute "DELETE FROM settings WHERE name in ('image_description_analysis')"
  end
end
