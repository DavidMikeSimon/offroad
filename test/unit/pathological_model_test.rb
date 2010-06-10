require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on the ability of model_extensions to correctly handle bad acts_as_mirrored_offline calls

class PathologicalModelTest < ActiveSupport::TestCase
  common_test "cannot specify acts_as_mirrored_offline multiple times" do
    assert_raise OfflineMirror::ModelError do
      class BrokenRecord < ActiveRecord::Base
        acts_as_mirrored_offline :global
        acts_as_mirrored_offline :global
      end
    end
  end
  
  common_test "cannot specify invalid mirror mode" do
    assert_raise OfflineMirror::ModelError do
      class BrokenRecord < ActiveRecord::Base
        acts_as_mirrored_offline :this_mode_does_not_exist
      end
    end
  end
  
  common_test "cannot specify :group_owned mode without :group_key" do
    assert_raise OfflineMirror::ModelError do
      class BrokenRecord < ActiveRecord::Base
        acts_as_mirrored_offline :group_owned # No :group_key
      end
    end
  end
  
  common_test "cannot specify :group_owned with a :group_key to a non-existing column" do
    assert_raise OfflineMirror::ModelError do
      class BrokenRecord < ActiveRecord::Base
        acts_as_mirrored_offline :group_owned, :group_key => :no_such_column
      end
    end
  end
  
  common_test "can specify :group_key without the _id prefix" do
    class BrokenRecord < ActiveRecord::Base
      acts_as_mirrored_offline :group_owned, :group_key => :group
    end
    assert_equal "group_id", BrokenRecord.offline_mirror_group_key.to_s
  end
  
  common_test "cannot give acts_as_mirrored_offline unknown options" do
    assert_raise OfflineMirror::ModelError do
      class BrokenRecord < ActiveRecord::Base
        acts_as_mirrored_offline :gruop_base, :foo_bar_bork_narf => 1234
      end
    end
  end
end

run_test_class PathologicalModelTest