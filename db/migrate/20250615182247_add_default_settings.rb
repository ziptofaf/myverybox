class AddDefaultSettings < ActiveRecord::Migration[7.1]
  def up
    time_now = Time.now.iso8601
    execute "INSERT INTO settings (name, value_type, value, created_at, updated_at) values ('expires_in_seconds', 'number', '0', '#{time_now}', '#{time_now}')"
    execute "INSERT INTO settings (name, value_type, value, created_at, updated_at) values ('remove_expired_files', 'bool', '1', '#{time_now}', '#{time_now}')"
  end
  
  def down
    execute "DELETE FROM settings WHERE name in ('expires_in_seconds', 'remove_expired_files')"
  end
end
