require 'active_support/concern'
require 'meta_search/method'
require 'meta_search/builder'

module MetaSearch
  module Searches

    module ActiveRecord

      def self.included(base)
        base.extend ClassMethods

        base.class_eval do
          class_attribute :_metasearch_include_attributes, :_metasearch_exclude_attributes
          class_attribute :_metasearch_include_associations, :_metasearch_exclude_associations
          class_attribute :_metasearch_methods
          self._metasearch_include_attributes =
            self._metasearch_exclude_attributes =
            self._metasearch_exclude_associations =
            self._metasearch_include_associations = []
          self._metasearch_methods = {}
        end
      end

      module ClassMethods
        # Prepares the search to run against your model. Returns an instance of
        # MetaSearch::Builder, which behaves pretty much like an ActiveRecord::Relation,
        # in that it doesn't actually query the database until you do something that
        # requires it to do so.
        def metasearch(params = nil, opts = nil)
          builder = Searches.for(self).new(self, opts || {})
          builder.build(params || {})
        end

        alias_method :search, :metasearch unless respond_to?(:search)

        private

        # Excludes model attributes from searchability. This means that searches can't be created against
        # these columns, whether the search is based on this model, or the model's attributes are being
        # searched by association from another model. If a Comment <tt>belongs_to :article</tt> but declares
        # <tt>attr_unsearchable :user_id</tt> then <tt>Comment.search</tt> won't accept parameters
        # like <tt>:user_id_equals</tt>, nor will an Article.search accept the parameter
        # <tt>:comments_user_id_equals</tt>.
        def attr_unsearchable(*args)
          args.flatten.each do |attr|
            attr = attr.to_s
            raise(ArgumentError, "No persisted attribute (column) named #{attr} in #{self}") unless self.columns_hash.has_key?(attr)
            self._metasearch_exclude_attributes = (self._metasearch_exclude_attributes + [attr]).uniq
          end
        end

        # Like <tt>attr_unsearchable</tt>, but operates as a whitelist rather than blacklist. If both
        # <tt>attr_searchable</tt> and <tt>attr_unsearchable</tt> are present, the latter
        # is ignored.
        def attr_searchable(*args)
          args.flatten.each do |attr|
            attr = attr.to_s
            raise(ArgumentError, "No persisted attribute (column) named #{attr} in #{self}") unless self.columns_hash.has_key?(attr)
            self._metasearch_include_attributes = (self._metasearch_include_attributes + [attr]).uniq
          end
        end

        # Excludes model associations from searchability. This mean that searches can't be created against
        # these associations. An article that <tt>has_many :comments</tt> but excludes comments from
        # searching by declaring <tt>assoc_unsearchable :comments</tt> won't make any of the
        # <tt>comments_*</tt> methods available.
        def assoc_unsearchable(*args)
          args.flatten.each do |assoc|
            assoc = assoc.to_s
            raise(ArgumentError, "No such association #{assoc} in #{self}") unless self.reflect_on_all_associations.map {|a| a.name.to_s}.include?(assoc)
            self._metasearch_exclude_associations = (self._metasearch_exclude_associations + [assoc]).uniq
          end
        end

        # As with <tt>attr_searchable</tt> this is the whitelist version of
        # <tt>assoc_unsearchable</tt>
        def assoc_searchable(*args)
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

        alias_method :search_method, :search_methods
      end
    end

    def self.for(klass)
      DISPATCH[klass]
    end

    private

    DISPATCH = Hash.new do |hash, klass|
      class_name = klass.name.gsub('::', '_')
      hash[klass] = module_eval <<-RUBY_EVAL
        class #{class_name} < MetaSearch::Builder
          def self.klass
            ::#{klass}
          end
        end

        #{class_name}
      RUBY_EVAL
    end
  end
end