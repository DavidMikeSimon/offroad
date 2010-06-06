class CreateMoreTables < ActiveRecord::Migration
  def self.up
    create_table :group_owned_records do |t|
      t.string :description
      t.integer :some_integer
      t.integer :group_id
      t.integer :parent_id
      t.integer :unmirrored_record_id
      t.integer :global_record_id
    end
    
    create_table :global_records do |t|
      t.string :title
      t.boolean :some_boolean
      t.integer :unmirrored_record_id
      t.integer :friend_id
      t.integer :some_group_id
    end
    
    create_table :unmirrored_records do |t|
      t.string :content
      t.float :some_float
    end
    
    create_table :broken_records do |t|
      t.integer :group_id
    end
  end
  
  def self.down
    drop_table :group_data
  end
end