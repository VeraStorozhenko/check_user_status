class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :idfa, null: false
      t.string :ban_status, null: false, default: "not_banned"

      t.timestamps
    end
    add_index :users, :idfa, unique: true
  end
end
