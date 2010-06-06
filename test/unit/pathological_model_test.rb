require File.dirname(__FILE__) + '/../test_helper'

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
  
  common_test "can specify :group_key either with or without _id prefix" do
    assert_nothing_raised do
    end
  end
end

run_test_class PathologicalModelTest