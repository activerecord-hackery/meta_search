require 'active_support/concern'
require 'meta_search/method'
require 'meta_search/builder'

module MetaSearch::Searches
  module ActiveRecord
    extend ActiveSupport::Concern
    
    included do
      class_attribute :_metasearch_include_attributes, :_metasearch_exclude_attributes
      class_attribute :_metasearch_include_associations, :_metasearch_exclude_associations
      class_attribute :_metasearch_methods
      self._metasearch_include_attributes =
        self._metasearch_exclude_attributes =
        self._metasearch_exclude_associations =
        self._metasearch_include_associations = []
      self._metasearch_methods = {}
        
      singleton_class.instance_eval do
        alias_method :metasearch_include_attr, :searchable_attributes
        alias_method :metasearch_exclude_attr, :non_searchable_attributes
        alias_method :metasearch_include_assoc, :searchable_associations
        alias_method :metasearch_exclude_assoc, :non_searchable_associations
      end
    end

    module ClassMethods
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
      # <tt>non_searchable_attributes :user_id</tt> then <tt>Comment.search</tt> won't accept parameters
      # like <tt>:user_id_equals</tt>, nor will an Article.search accept the parameter
      # <tt>:comments_user_id_equals</tt>.
      def non_searchable_attributes(*args)
        args.flatten.each do |attr|
          attr = attr.to_s
          raise(ArgumentError, "No persisted attribute (column) named #{attr} in #{self}") unless self.columns_hash.has_key?(attr)
          self._metasearch_exclude_attributes = (self._metasearch_exclude_attributes + [attr]).uniq
        end
      end

      # Like non_searchable_attributes, but operates as a whitelist rather than blacklist. If both
      # <tt>searchable_attributes</tt> and <tt>non_searchable_attributes</tt> are present, the latter
      # is ignored.
      def searchable_attributes(*args)
        args.flatten.each do |attr|
          attr = attr.to_s
          raise(ArgumentError, "No persisted attribute (column) named #{attr} in #{self}") unless self.columns_hash.has_key?(attr)
          self._metasearch_include_attributes = (self._metasearch_include_attributes + [attr]).uniq
        end
      end
      
      # Excludes model associations from searchability. This mean that searches can't be created against
      # these associations. An article that <tt>has_many :comments</tt> but excludes comments from
      # searching by declaring <tt>non_searchable_associations :comments</tt> won't make any of the
      # <tt>comments_*</tt> methods available.
      def non_searchable_associations(*args)
        args.flatten.each do |assoc|
          assoc = assoc.to_s
          raise(ArgumentError, "No such association #{assoc} in #{self}") unless self.reflect_on_all_associations.map {|a| a.name.to_s}.include?(assoc)
          self._metasearch_exclude_associations = (self._metasearch_exclude_associations + [assoc]).uniq
        end
      end
      
      # As with <tt>searchable_attributes</tt> this is the whitelist version of <tt>non_searchable_associations</tt>
      def searchable_associations(*args)
        args.flatten.each do |assoc|
          assoc = assoc.to_s
          raise(ArgumentError, "No such association #{assoc} in #{self}") unless self.reflect_on_all_associations.map {|a| a.name.to_s}.include?(assoc)
          self._metasearch_include_associations = (self._metasearch_include_associations + [assoc]).uniq
        end
      end
      
      def search_methods(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        args.flatten.map(&:to_s).each do |arg|
          self._metasearch_methods[arg] = MetaSearch::Method.new(arg, opts)
        end
      end
    end
  end
end