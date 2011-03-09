class CreateTables < ActiveRecord::Migration
  def self.up
    create_table :groups do |t|
      t.string :name
      t.integer :favorite_id
      t.integer :unmirrored_record_id
      t.integer :global_record_id
      t.timestamps
    end
    
    create_table :group_owned_records do |t|
      t.string :description
      t.integer :some_integer
      t.integer :should_be_even, :default => 0
      t.integer :group_id
      t.integer :parent_id
      t.integer :unmirrored_record_id
      t.integer :global_record_id
      t.integer :protected_integer, :default => 1
      t.timestamps
    end

    create_table :sub_records do |t|
      t.string :description
      t.integer :group_owned_record_id
      t.integer :unmirrored_record_id
      t.integer :buddy_id
      t.timestamps
    end

    create_table :group_single_records do |t|
      t.string :description
      t.timestamps
    end
    
    create_table :global_records do |t|
      t.string :title
      t.boolean :some_boolean
      t.integer :should_be_odd, :default => 1
      t.integer :unmirrored_record_id
      t.integer :friend_id
      t.integer :some_group_id
      t.integer :protected_integer, :default => 1
      t.timestamps
    end
    
    create_table :unmirrored_records do |t|
      t.string :content
      t.float :some_float
      t.timestamps
    end
    
    create_table :broken_records do |t|
      t.integer :group_id
    end
  end
  
  def self.down
    drop_table :groups
    drop_table :group_owned_records
    drop_table :unmirrored_records
    drop_table :broken_records
  end
end
