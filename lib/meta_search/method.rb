require 'meta_search/utility'

module MetaSearch
  # MetaSearch can be given access to any class method on your model to extend its search capabilities.
  # The only rule is that the method must return an ActiveRecord::Relation so that MetaSearch can
  # continue to extend the search with other attributes. Conveniently, scopes (formerly "named scopes")
  # do this already.
  #
  # Consider the following model:
  #
  #   class Company < ActiveRecord::Base
  #     has_many :slackers, :class_name => "Developer", :conditions => {:slacker => true}
  #     scope :backwards_name, lambda {|name| where(:name => name.reverse)}
  #     scope :with_slackers_by_name_and_salary_range,
  #       lambda {|name, low, high|
  #         joins(:slackers).where(:developers => {:name => name, :salary => low..high})
  #       }
  #   end
  #
  # To allow MetaSearch access to a model method, including a named scope, just use
  # <tt>search_methods</tt> in the model:
  #
  #   search_methods :backwards_name
  #
  # This will allow you to add a text field named :backwards_name to your search form, and
  # it will behave as you might expect.
  #
  # In the case of the second scope, we have multiple parameters to pass in, of different
  # types. We can pass the following to <tt>search_methods</tt>:
  #
  #   search_methods :with_slackers_by_name_and_salary_range,
  #     :splat_param => true, :type => [:string, :integer, :integer]
  #
  # MetaSearch needs us to tell it that we don't want to keep the array supplied to it as-is, but
  # "splat" it when passing it to the model method. And in this case, ActiveRecord would have been
  # smart enough to handle the typecasting for us, but I wanted to demonstrate how we can tell
  # MetaSearch that a given parameter is of a specific database "column type." This is just a hint
  # MetaSearch uses in the same way it does when casting "Where" params based on the DB column
  # being searched. It's also important so that things like dates get handled properly by FormBuilder.
  #
  # _NOTE_: If you do supply an array, rather than a single type value, to <tt>:type</tt>, MetaSearch
  # will enforce that any array supplied for input by your forms has the correct number of elements
  # for your eventual method.
  #
  # Besides <tt>:splat_param</tt> and <tt>:type</tt>, search_methods accept the same <tt>:formatter</tt>
  # and <tt>:validator</tt> options that you would use when adding a new MetaSearch::Where:
  #
  # <tt>formatter</tt> is the Proc that will do any formatting to the variable passed to your method.
  # The default proc is <tt>{|param| param}</tt>, which doesn't really do anything. If you pass a
  # string, it will be +eval+ed in the context of this Proc.
  #
  # If your method will do a LIKE search against its parameter, you might want to pass:
  #
  #   :formatter => '"%#{param}%"'
  #
  # Be sure to single-quote the string, so that variables aren't interpolated until later. If in doubt,
  # just use a Proc, like so:
  #
  #   :formatter => Proc.new {|param| "%#{param}%"}
  #
  # <tt>validator</tt> is the Proc that will be used to check whether a parameter supplied to the
  # method is valid. If it is not valid, it won't be used in the query. The default is
  # <tt>{|param| !param.blank?}</tt>, so that empty parameters aren't added to the search, but you
  # can get more complex if you desire. Validations are run after typecasting, so you can check
  # the class of your parameters, for instance.
  class Method
    include Utility

    attr_reader :name, :formatter, :validator, :type

    def initialize(name, opts ={})
      raise ArgumentError, "Name parameter required" if name.blank?
      @name = name
      @type = opts[:type] || :string
      @splat_param = opts[:splat_param] || false
      @formatter = opts[:formatter] || Proc.new {|param| param}
      if @formatter.is_a?(String)
        formatter = @formatter
        @formatter = Proc.new {|param| eval formatter}
      end
      unless @formatter.respond_to?(:call)
        raise ArgumentError, "Invalid formatter for #{name}, should be a Proc or String."
      end
      @validator = opts[:validator] || Proc.new {|param| !param.blank?}
      unless @validator.respond_to?(:call)
        raise ArgumentError, "Invalid validator for #{name}, should be a Proc."
      end
    end

    # Cast the parameter to the type specified in the Method's <tt>type</tt>
    def cast_param(param)
      if type.is_a?(Array)
        unless param.is_a?(Array) && param.size == type.size
          num_params = param.is_a?(Array) ? param.size : 1
          raise ArgumentError, "Parameters supplied to #{name} could not be type cast -- #{num_params} values supplied, #{type.size} expected"
        end
        type.each_with_index do |t, i|
          param[i] = cast_attributes(t, param[i])
        end
        param
      else
        cast_attributes(type, param)
      end
    end

    # Evaluate the method in the context of the supplied relation and parameter
    def evaluate(relation, param)
      if splat_param?
        relation.send(name, *format_param(param))
      else
        relation.send(name, format_param(param))
      end
    end

    def splat_param?
      !!@splat_param
    end

    # Format a parameter for searching using the Method's defined formatter.
    def format_param(param)
      formatter.call(param)
    end

    # Validate the parameter for use in a search using the Method's defined validator.
    def validate(param)
      validator.call(param)
    end
  end
end