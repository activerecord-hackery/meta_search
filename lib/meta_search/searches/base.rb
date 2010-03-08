require 'meta_search/builder'

module MetaSearch
  module Searches
    module Base
      # Prepares the search to run against your model. Returns an instance of
      # MetaSearch::Builder, which behaves pretty much like an ActiveRecord::Relation,
      # in that it doesn't actually query the database until you do something that
      # requires it to do so.
      #
      # Options:
      #
      # * <tt>:exclude_associations</tt> - An array of association names to exclude from search.
      # * <tt>:exclude_attributes</tt> - An array of attributes (of the model you're searching)
      #   to exclude from searching.
      #
      # _NOTE_: Attributes of associations can't be excluded. It's all or nothing, for now.
      def search(opts = {})
        opts ||= {} # to catch nil params
        search_options = opts.delete(:search_options) || {}
        builder = MetaSearch::Builder.new(self, search_options)
        builder.build(opts)
      end
    end
  end
end