require 'spec_helper'

module MetaSearch
  describe Configuration do
    it 'yields self on configure' do
      MetaSearch.configure do
        self.should eq MetaSearch::Configuration
      end
    end
  end
end