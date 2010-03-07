module MetaSearch
  # Just a little module to mix in so that ActionPack doesn't complain.
  module ModelCompatibility
    def new_record?
      false
    end
  end
end