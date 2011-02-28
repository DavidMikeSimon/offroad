require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to correctly handle bad acts_as_offroadable calls

class PathologicalModelTest < Test::Unit::TestCase
  agnostic_test "cannot specify acts_as_offroadable multiple times" do
    assert_raise Offroad::ModelError do
      class MultipleTimesBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_offroadable :global
        acts_as_offroadable :global
      end
    end
  end
  
  agnostic_test "cannot specify invalid mirror mode" do
    assert_raise Offroad::ModelError do
      class InvalidModeBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_offroadable :this_mode_does_not_exist
      end
    end
  end
  
  agnostic_test "cannot specify :group_owned mode without :parent" do
    assert_raise Offroad::ModelError do
      class NoGroupKeyBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_offroadable :group_owned # No :parent
      end
    end
  end
  
  agnostic_test "cannot specify :group_owned with a :parent to a non-existing association" do
    self.class.send(:remove_const, :InvalidColumnBrokenRecord) if self.class.const_defined?(:InvalidColumnBrokenRecord)
    assert_raise Offroad::ModelError do
      class InvalidColumnBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_offroadable :group_owned, :parent => :no_such_assoc
      end
      InvalidColumnBrokenRecord.create
    end
  end
  
  agnostic_test "cannot give acts_as_offroadable unknown options" do
    assert_raise Offroad::ModelError do
      class UnknownOptionsBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_offroadable :global, :foo_bar_bork_narf => 1234
      end
    end
  end
  
  agnostic_test "cannot specify more than one group base" do
    # The Group model has already declare itself as :group base
    assert_raise Offroad::ModelError do
      class DoubleGroupBaseBrokenRecord < ActiveRecord::Base
        acts_as_offroadable :group_base
      end
    end
  end
end
