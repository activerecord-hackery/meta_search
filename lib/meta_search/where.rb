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
  # * _does_not_equal_ (alias: _ne_) - The opposite of equals, oddly enough.
  # * _in_ - Takes an array, matches on equality with any of the items in the array.
  # * _not_in_ (alias: _ni_) - Like above, but negated.
  #
  # === Strings
  #
  # * _contains_ (alias: _like_) - Substring match.
  # * _does_not_contain_ (alias: _nlike_) - Negative substring match.
  # * _starts_with_ (alias: _sw_) - Match strings beginning with the entered term.
  # * _does_not_start_with_ (alias: _dnsw_) - The opposite of above.
  # * _ends_with_ (alias: _ew_) - Match strings ending with the entered term.
  # * _does_not_end_with_ (alias: _dnew_) - Negative of above.
  #
  # === Numbers, dates, and times
  #
  # * _greater_than_ (alias: _gt_) - Greater than.
  # * _greater_than_or_equal_to_ (alias: _gte_) - Greater than or equal to.
  # * _less_than_ (alias: _lt_) - Less than.
  # * _less_than_or_equal_to_ (alias: _lte_) - Less than or equal to.
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
  class Where
    attr_reader :name, :aliases, :types, :condition, :formatter, :validator
    def initialize(where)
      if [String,Symbol].include?(where.class)
        where = Where.get(where) or raise ArgumentError("A where could not be instantiated for the argument #{where}")
      end
      @name = where[:name]
      @aliases = where[:aliases]
      @types = where[:types]
      @condition = where[:condition]
      @validator = where[:validator]
      @formatter = where[:formatter]
    end
        
    def format_param(param)
      formatter.call(param)
    end
    
    def validate(param)
      validator.call(param)
    end
    
    class << self
      # At application initialization, you can add additional custom Wheres to the mix.
      # in your application's <tt>config/initializers/meta_search.rb</tt>, place lines
      # like this:
      #
      # MetaSearch::Where.add :between, :btw,
      #   :condition => :in,
      #   :types => [:integer, :float, :decimal, :date, :datetime, :timestamp, :time],
      #   :formatter => Proc.new {|param| Range.new(param.first, param.last)},
      #   :validator => Proc.new {|param|
      #     param.is_a?(Array) && !(param[0].blank? || param[1].blank?)
      #   }
      #
      # The first options are all names for the where. Well, the first is a name, the rest
      # are aliases, really. They will determine the suffix you will use to access your Where.
      #
      # <tt>types</tt> is an array of types the comparison is valid for. The where will not
      # be available against columns that are not one of these types. Default is +ALL_TYPES+,
      # Which is one of several MetaSearch constants available for type assignment (the others
      # being +DATES+, +TIIMES+, +STRINGS+, and +NUMBERS+).
      #
      # <tt>condition</tt> is the Arel::Attribute predication (read: conditional operator) used
      # for the comparison. Default is :eq, or equality.
      #
      # <tt>substitutions</tt> is the text that comes next. It's normally going to have some
      # question marks in it (for variable substitution) if it's going to be of much use. The
      # default is ?. Keep in mind if you use more than one ? MetaSearch will require an array
      # be passed to the attribute for substitution.
      #
      # <tt>keep_arrays</tt> tells MetaSearch that if any arrays are received as parameters, they
      # should be used as-is in the substitution, rather than flattened and passed as a list.
      # For example, this is the definition of the "in" Where:
      #
      #   ['in', {:types => ALL_TYPES, :condition => 'IN', :substitutions => '(?)',
      #    :keep_arrays => true}]
      #
      # <tt>formatter</tt> is the Proc that will do any formatting to the variables to be substituted.
      # The default proc is <tt>{|param| param}</tt>, which doesn't really do anything. If you pass a
      # string, it will be +eval+ed in the context of this Proc.
      #
      # For example, this is the definition of the "contains" Where:
      #
      #   ['contains', 'like', {:types => STRINGS, :condition => 'LIKE', :formatter => '"%#{param}%"'}]
      #
      # Be sure to single-quote the string, so that variables aren't interpolated until later. If in doubt,
      # just use a Proc.
      def add(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        args = args.compact.flatten.map {|a| a.to_s }
        raise ArgumentError, "Name parameter required" if args.blank?
        opts[:name] ||= args.first
        opts[:types] ||= ALL_TYPES
        opts[:types] = [opts[:types]].flatten
        opts[:condition] ||= :eq
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
      end
      
      # Returns the complete array of Wheres
      def all
        @@wheres
      end
      
      # Get the where matching a method or condition.
      def get(method_id_or_condition)
        return nil unless where_key = @@wheres.keys.
          sort {|a,b| b.length <=> a.length}.
          detect {|n| method_id_or_condition.to_s.match(/#{n}=?$/)}
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
    end
  end
  
  Where.initialize_wheres
end