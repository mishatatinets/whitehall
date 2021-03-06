class CreateDetailedGuideUserNeeds < ActiveRecord::Migration
  def up
    create_table :user_needs, force: true do |t|
      t.string :user
      t.string :need
      t.string :goal
      t.references :organisation
      t.timestamps
    end

    create_table :edition_user_needs, force: true do |t|
      t.references :edition
      t.references :user_need
      t.timestamps
    end

    add_index :edition_user_needs, :edition_id
    add_index :user_needs, :organisation_id
  end

  def down
    drop_table :user_needs
    drop_table :edition_user_needs
  end
end
