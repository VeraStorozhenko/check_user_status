class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :idfa
      t.string :ban_status

      t.timestamps
    end
    add_index :users, :idfa, unique: true
  end
end
