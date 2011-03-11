class GroupOwnedRecord < ActiveRecord::Base
  belongs_to :group
  acts_as_offroadable :group_owned, :parent => :group

  belongs_to :parent, :class_name => "GroupOwnedRecord"
  belongs_to :unmirrored_record
  belongs_to :global_record
  has_many :children, :foreign_key => "parent_id", :class_name => "GroupOwnedRecord"
  has_many :subrecords
  validates_presence_of :description, :group
  validates_numericality_of :should_be_even, :even => true
  attr_protected :protected_integer
  
  def to_s
    description
  end

  def before_save
    @@callback_called = true
  end

  def after_save
    @@callback_called = true
  end

  def before_destroy
    @@callback_called = true
  end

  def after_destroy
    @@callback_called = true
  end

  def self.reset_callback_called
    @@callback_called = false
  end

  def self.callback_called
    @@callback_called
  end
end
