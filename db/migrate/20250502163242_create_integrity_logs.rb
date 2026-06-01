class CreateIntegrityLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :integrity_logs do |t|
      t.references :user, null: false, foreign_key: true

      t.string :idfa, null: false
      t.string :ban_status, null: false
      t.string :ip
      t.boolean :rooted_device, null: false, default: false
      t.string :country
      t.boolean :proxy, null: false, default: false
      t.boolean :vpn, null: false, default: false

      t.timestamps
    end
  end
end
