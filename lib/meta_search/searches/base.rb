require 'active_support/concern'
require 'meta_search/builder'

module MetaSearch
  module Searches
    module Base
      # Prepares the search to run against your model. Returns an instance of
      # MetaSearch::Builder, which behaves pretty much like an ActiveRecord::Relation,
      # in that it doesn't actually query the database until you do something that
      # requires it to do so.
      def search(opts = {})
        opts ||= {} # to catch nil params
        search_options = opts.delete(:search_options) || {}
        builder = MetaSearch::Builder.new(self, search_options)
        builder.build(opts)
      end
    
      private
    
      # Excludes model attributes from searchability. This means that searches can't be created against
      # these columns, whether the search is based on this model, or the model's attributes are being
      # searched by association from another model. If a Comment <tt>belongs_to :article</tt> but declares
      # <tt>metasearch_exclude_attr :user_id</tt> then <tt>Comment.search</tt> won't accept parameters
      # like <tt>:user_id_equals</tt>, nor will an Article.search accept the parameter
      # <tt>:comments_user_id_equals</tt>.
      def metasearch_exclude_attr(*args)
        args.each do |attr|
          attr = attr.to_s
          raise(ArgumentError, "No persisted attribute (column) named #{attr} in #{self}") unless self.columns_hash.has_key?(attr)
          self._metasearch_exclude_attributes = (self._metasearch_exclude_attributes + [attr]).uniq
        end
      end
    
      # Excludes model associations from searchability. This mean that searches can't be created against
      # these associations. An article that <tt>has_many :comments</tt> but excludes comments from
      # searching by declaring <tt>metasearch_exclude_assoc :comments</tt> won't make any of the
      # <tt>comments_*</tt> methods available.
      def metasearch_exclude_assoc(*args)
        args.each do |assoc|
          assoc = assoc.to_s
          raise(ArgumentError, "No such association #{assoc} in #{self}") unless self.reflect_on_all_associations.map {|a| a.name.to_s}.include?(assoc)
          self._metasearch_exclude_associations = (self._metasearch_exclude_associations + [assoc]).uniq
        end
      end
    end
  end
end