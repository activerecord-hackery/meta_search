require 'meta_search/exceptions'

module MetaSearch
  # Wheres are how MetaSearch does its magic. Wheres have a name (and possible aliases) which are
  # appended to your model and association attributes. When you instantiate a MetaSearch::Builder
  # against a model (manually or by calling your model's +search+ method) the builder responds to
  # methods named for your model's attributes and associations, suffixed by the name of the Where.
  #
  # These are the default Wheres, broken down by the types of ActiveRecord columns they can search
  # against:
  #
  # === All data types
  #
  # * _equals_ (alias: _eq_) - Just as it sounds.
  # * _does_not_equal_ (aliases: _ne_, _noteq_) - The opposite of equals, oddly enough.
  # * _in_ - Takes an array, matches on equality with any of the items in the array.
  # * _not_in_ (aliases: _ni_, _notin_) - Like above, but negated.
  # * _is_null_ - The column has an SQL NULL value.
  # * _is_not_null_ - The column contains anything but NULL.
  #
  # === Strings
  #
  # * _contains_ (aliases: _like_, _matches_) - Substring match.
  # * _does_not_contain_ (aliases: _nlike_, _nmatches_) - Negative substring match.
  # * _starts_with_ (alias: _sw_) - Match strings beginning with the entered term.
  # * _does_not_start_with_ (alias: _dnsw_) - The opposite of above.
  # * _ends_with_ (alias: _ew_) - Match strings ending with the entered term.
  # * _does_not_end_with_ (alias: _dnew_) - Negative of above.
  #
  # === Numbers, dates, and times
  #
  # * _greater_than_ (alias: _gt_) - Greater than.
  # * _greater_than_or_equal_to_ (aliases: _gte_, _gteq_) - Greater than or equal to.
  # * _less_than_ (alias: _lt_) - Less than.
  # * _less_than_or_equal_to_ (aliases: _lte_, _lteq_) - Less than or equal to.
  #
  # === Booleans
  #
  # * _is_true_ - Is true. Useful for a checkbox like "only show admin users".
  # * _is_false_ - The complement of _is_true_.
  #
  # === Non-boolean data types
  #
  # * _is_present_ - As with _is_true_, useful with a checkbox. Not NULL or the empty string.
  # * _is_blank_ - Returns records with a value of NULL or the empty string in the column.
  #
  # So, given a model like this...
  #
  #   class Article < ActiveRecord::Base
  #     belongs_to :author
  #     has_many :comments
  #     has_many :moderations, :through => :comments
  #   end
  #
  # ...you might end up with attributes like <tt>title_contains</tt>,
  # <tt>comments_title_starts_with</tt>, <tt>moderations_value_less_than</tt>,
  # <tt>author_name_equals</tt>, and so on.
  #
  # Additionally, all of the above predicate types also have an _any and _all version, which
  # expects an array of the corresponding parameter type, and requires any or all of the
  # parameters to be a match, respectively. So:
  #
  #   Article.search :author_name_starts_with_any => ['Jim', 'Bob', 'Fred']
  #
  # will match articles authored by Jimmy, Bobby, or Freddy, but not Winifred.
  class Where
    attr_reader :name, :aliases, :types, :cast, :predicate, :formatter, :validator
    def initialize(where)
      if [String,Symbol].include?(where.class)
        where = Where.get(where) or raise ArgumentError("A where could not be instantiated for the argument #{where}")
      end
      @name = where[:name]
      @aliases = where[:aliases]
      @types = where[:types]
      @cast = where[:cast]
      @predicate = where[:predicate]
      @validator = where[:validator]
      @formatter = where[:formatter]
      @splat_param = where[:splat_param]
      @skip_compounds = where[:skip_compounds]
    end

    def splat_param?
      !!@splat_param
    end

    def skip_compounds?
      !!@skip_compounds
    end

    # Format a parameter for searching using the Where's defined formatter.
    def format_param(param)
      formatter.call(param)
    end

    # Validate the parameter for use in a search using the Where's defined validator.
    def validate(param)
      validator.call(param)
    end

    # Evaluate the Where for the given relation, attribute, and parameter(s)
    def evaluate(relation, attributes, param)
      if splat_param?
        conditions = attributes.map {|a| a.send(predicate, *format_param(param))}
      else
        conditions = attributes.map {|a| a.send(predicate, format_param(param))}
      end

      relation.where(conditions.inject(nil) {|memo, c| memo ? memo.or(c) : c})
    end

    class << self
      # At application initialization, you can add additional custom Wheres to the mix.
      # in your application's <tt>config/initializers/meta_search.rb</tt>, place lines
      # like this:
      #
      #   MetaSearch::Where.add :between, :btw,
      #     :predicate => :in,
      #     :types => [:integer, :float, :decimal, :date, :datetime, :timestamp, :time],
      #     :formatter => Proc.new {|param| Range.new(param.first, param.last)},
      #     :validator => Proc.new {|param|
      #       param.is_a?(Array) && !(param[0].blank? || param[1].blank?)
      #     }
      #
      # The first options are all names for the where. Well, the first is a name, the rest
      # are aliases, really. They will determine the suffix you will use to access your Where.
      #
      # <tt>types</tt> is an array of types the comparison is valid for. The where will not
      # be available against columns that are not one of these types. Default is +ALL_TYPES+,
      # Which is one of several MetaSearch constants available for type assignment (the others
      # being +DATES+, +TIIMES+, +STRINGS+, and +NUMBERS+).
      #
      # <tt>predicate</tt> is the Arel::Attribute predication (read: conditional operator) used
      # for the comparison. Default is :eq, or equality.
      #
      # <tt>formatter</tt> is the Proc that will do any formatting to the variables to be substituted.
      # The default proc is <tt>{|param| param}</tt>, which doesn't really do anything. If you pass a
      # string, it will be +eval+ed in the context of this Proc.
      #
      # For example, this is the definition of the "contains" Where:
      #
      #   ['contains', 'like', {:types => STRINGS, :predicate => :matches, :formatter => '"%#{param}%"'}]
      #
      # Be sure to single-quote the string, so that variables aren't interpolated until later. If in doubt,
      # just use a Proc.
      #
      # <tt>validator</tt> is the Proc that will be used to check whether a parameter supplied to the
      # Where is valid. If it is not valid, it won't be used in the query. The default is
      # <tt>{|param| !param.blank?}</tt>, so that empty parameters aren't added to the search, but you
      # can get more complex if you desire, like the one in the between example, above.
      #
      # <tt>splat_param</tt>, if true, will cause the parameters sent to the predicate in question
      # to be splatted (converted to an argument list). This is not normally useful and defaults to
      # false, but is used when automatically creating compound Wheres (*_any, *_all) so that the
      # Arel attribute method gets the correct parameter list.
      #
      # <tt>skip_compounds</tt> will prevent creation of compound condition methods (ending in
      # _any_ or _all_) for situations where they wouldn't make sense, such as the built-in
      # conditions <tt>is_true</tt> and <tt>is_false</tt>.
      #
      # <tt>cast</tt> will override the normal cast of the parameter when using this Where
      # condition. Normally, the value supplied to a condition is cast to the type of the column
      # it's being compared against. In cases where this isn't desirable, because the value you
      # intend to accept isn't the same kind of data you'll be comparing against, you can override
      # that cast here, using one of the standard DB type symbols such as :integer, :string, :boolean
      # and so on.
      def add(*args)
        where = create_where_from_args(*args)
        create_where_compounds_for(where) unless where.skip_compounds?
      end

      # Returns the complete array of Wheres
      def all
        @@wheres
      end

      # Get the where matching a method or predicate.
      def get(method_id_or_predicate)
        return nil unless where_key = @@wheres.keys.
          sort {|a,b| b.length <=> a.length}.
          detect {|n| method_id_or_predicate.to_s.match(/#{n}=?$/)}
        where = @@wheres[where_key]
        where = @@wheres[where] if where.is_a?(String)
        where
      end

      # Set the wheres to their default values, removing any customized settings.
      def initialize_wheres
        @@wheres = {}
        DEFAULT_WHERES.each do |where|
          add(*where)
        end
      end

      private

      # "Creates" the Where by adding it (and its aliases) to the current hash of wheres. It then
      # instantiates a Where and returns it for use.
      def create_where_from_args(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        args = args.compact.flatten.map {|a| a.to_s }
        raise ArgumentError, "Name parameter required" if args.blank?
        opts[:name] ||= args.first
        opts[:types] ||= ALL_TYPES
        opts[:types] = [opts[:types]].flatten
        opts[:cast] = opts[:cast]
        opts[:predicate] ||= :eq
        opts[:splat_param] ||= false
        opts[:skip_compounds] ||= false
        opts[:formatter] ||= Proc.new {|param| param}
        if opts[:formatter].is_a?(String)
          formatter = opts[:formatter]
          opts[:formatter] = Proc.new {|param| eval formatter}
        end
        unless opts[:formatter].respond_to?(:call)
          raise ArgumentError, "Invalid formatter for #{opts[:name]}, should be a Proc or String."
        end
        opts[:validator] ||= Proc.new {|param| !param.blank?}
        unless opts[:validator].respond_to?(:call)
          raise ArgumentError, "Invalid validator for #{opts[:name]}, should be a Proc."
        end
        opts[:aliases] ||= [args - [opts[:name]]].flatten
        @@wheres ||= {}
        if @@wheres.has_key?(opts[:name])
          raise ArgumentError, "\"#{opts[:name]}\" is not available for use as a where name."
        end
        @@wheres[opts[:name]] = opts
        opts[:aliases].each do |a|
          if @@wheres.has_key?(a)
            opts[:aliases].delete(a)
          else
            @@wheres[a] = opts[:name]
          end
        end
        new(opts[:name])
      end

      # Takes the provided +where+ param and derives two additional Wheres from it, with the
      # name appended by _any/_all. These will use Arel's grouped predicate methods (matching
      # the same naming convention) to be invoked instead, with a list of possible/required
      # matches.
      def create_where_compounds_for(where)
        ['any', 'all'].each do |compound|
          args = [where.name, *where.aliases].map {|n| "#{n}_#{compound}"}
          create_where_from_args(*args + [{
            :types => where.types,
            :predicate => "#{where.predicate}_#{compound}".to_sym,
            # Only use valid elements in the array
            :formatter => Proc.new {|param|
              param.select {|p| where.validator.call(p)}.map {|p| where.formatter.call(p)}
            },
            # Compound where is valid if it has at least one element which is valid
            :validator => Proc.new {|param|
              param.is_a?(Array) &&
              !param.select {|p| where.validator.call(p)}.blank?}
            }]
          )
        end
      end
    end
  end

  Where.initialize_wheres
end