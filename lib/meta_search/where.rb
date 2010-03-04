module MetaSearch
  class Where    
    class << self
      def add(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        args = args.compact.flatten.map {|a| a.to_s }
        raise ArgumentError, "Name parameter required" if args.blank?
        opts[:name] ||= args.first
        opts[:types] ||= ALL_TYPES
        opts[:types].flatten!
        opts[:conditional] ||= '='
        opts[:substitutions] ||= '?'
        opts[:formatter] ||= Proc.new {|param| param}
        if opts[:formatter].is_a?(String)
          formatter = opts[:formatter]
          opts[:formatter] = Proc.new {|param| eval formatter}
        end
        opts[:aliases] ||= args - [opts[:name]]
        @@wheres ||= {}
        @@wheres[opts[:name]] = opts
        opts[:aliases].each do |a|
          @@wheres[a] = opts[:name]
        end
      end
    
      def all
        @@wheres
      end
    
      def get(method_id_or_condition)
        return nil unless where_key = @@wheres.keys.detect {|n| method_id_or_condition.to_s.match(/#{n}=?$/)}
        where = @@wheres[where_key]
        where = @@wheres[where] if where.is_a?(String)
        where
      end
    
      def initialize_wheres
        DEFAULT_WHERES.each do |where|
          add(*where)
        end
      end
    end
  end
  
  Where.initialize_wheres
end