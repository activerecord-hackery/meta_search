require 'meta_search'

module MetaSearch
  class Railtie < Rails::Railtie #:nodoc:
    railtie_name :meta_search
    
    initializer "meta_search.active_record" do |app|
      if defined? ::ActiveRecord
        require 'meta_search/searches/active_record'
        MetaSearch::Searches::ActiveRecord.enable!
      end
    end
    
    initializer "meta_search.action_view" do |app|
      if defined? ::ActionView
        require 'meta_search/helpers/action_view'
        MetaSearch::Helpers::FormBuilder.enable!
      end
    end
  end
end