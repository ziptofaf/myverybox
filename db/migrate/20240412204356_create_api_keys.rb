class CreateApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :api_keys do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :value
      t.boolean :active

      t.timestamps
    end
  end
end
