module MetaSearch
  class Method
    attr_reader :name, :formatter, :validator, :type
    
    def initialize(name, opts ={})
      raise ArgumentError, "Name parameter required" if name.blank?
      @name = name
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
      @type = opts[:type] || :string
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