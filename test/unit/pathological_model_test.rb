require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on the ability of model_extensions to correctly handle bad acts_as_mirrored_offline calls

class PathologicalModelTest < Test::Unit::TestCase
  common_test "cannot specify acts_as_mirrored_offline multiple times" do
    assert_raise OfflineMirror::ModelError do
      class MultipleTimesBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_mirrored_offline :global
        acts_as_mirrored_offline :global
      end
    end
  end
  
  common_test "cannot specify invalid mirror mode" do
    assert_raise OfflineMirror::ModelError do
      class InvalidModeBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_mirrored_offline :this_mode_does_not_exist
      end
    end
  end
  
  common_test "cannot specify :group_owned mode without :group_key" do
    assert_raise OfflineMirror::ModelError do
      class NoGroupKeyBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_mirrored_offline :group_owned # No :group_key
      end
    end
  end
  
  common_test "cannot specify :group_owned with a :group_key to a non-existing column" do
    class InvalidColumnBrokenRecord < ActiveRecord::Base
      set_table_name "broken_records"
      acts_as_mirrored_offline :group_owned, :group_key => :no_such_column
    end
    assert_raise OfflineMirror::ModelError do
      InvalidColumnBrokenRecord.create
    end
  end
  
  common_test "cannot give acts_as_mirrored_offline unknown options" do
    assert_raise OfflineMirror::ModelError do
      class UnknownOptionsBrokenRecord < ActiveRecord::Base
        set_table_name "broken_records"
        acts_as_mirrored_offline :global, :foo_bar_bork_narf => 1234
      end
    end
  end
  
  common_test "cannot specify more than one group base" do
    # The Group model has already declare itself as :group base
    assert_raise OfflineMirror::ModelError do
      class DoubleGroupBaseBrokenRecord < ActiveRecord::Base
        acts_as_mirrored_offline :group_base
      end
    end
  end
end