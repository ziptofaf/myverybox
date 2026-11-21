# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Default system settings. These are also inserted by migrations
# (AddDefaultSettings, AddImageDescriptionAnalysisSetting), but a database built
# from schema.rb (db:setup / db:prepare / db:schema:load) never runs those, so
# seed them here too. find_or_create_by! keeps existing values untouched.
[
  { name: 'expires_in_seconds',         value_type: 'number', value: '0' },
  { name: 'remove_expired_files',       value_type: 'bool',   value: '1' },
  { name: 'image_description_analysis', value_type: 'bool',   value: '0' }
].each do |attrs|
  Setting.find_or_create_by!(name: attrs[:name]) do |setting|
    setting.value_type = attrs[:value_type]
    setting.value = attrs[:value]
  end
end
