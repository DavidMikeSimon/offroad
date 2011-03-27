if HOBO_TEST_MODE
  class Guest < Hobo::Guest
    def administrator?
      false
    end
  end
end
