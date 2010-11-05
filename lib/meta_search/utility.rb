require 'meta_search/exceptions'

module MetaSearch
  module Utility #:nodoc:

    TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE'].to_set
    FALSE_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE'].to_set

    private

    def preferred_method_name(method_id)
      method_name = method_id.to_s
      where = Where.new(method_name) rescue nil
      return nil unless where
      where.aliases.each do |a|
        break if method_name.sub!(/#{a}(=?)$/, "#{where.name}\\1")
      end
      method_name
    end

    def array_of_strings?(o)
      o.is_a?(Array) && o.all?{|obj| obj.is_a?(String)}
    end

    def array_of_arrays?(vals)
      vals.is_a?(Array) && vals.first.is_a?(Array)
    end

    def array_of_dates?(vals)
      vals.is_a?(Array) && vals.first.respond_to?(:to_time)
    end

    def cast_attributes(type, vals)
      if array_of_arrays?(vals)
        vals.map! {|v| cast_attributes(type, v)}
      # Need to make sure not to kill multiparam dates/times
      elsif vals.is_a?(Array) && (array_of_dates?(vals) || !(DATES+TIMES).include?(type))
        vals.map! {|v| cast_attribute(type, v)}
      else
        cast_attribute(type, vals)
      end
    end

    def cast_attribute(type, val)
      case type
      when *STRINGS
        val.respond_to?(:to_s) ? val.to_s : String.new(val)
      when *DATES
        if val.respond_to?(:to_date)
          val.to_date rescue nil
        else
          y, m, d = *[val].flatten
          m ||= 1
          d ||= 1
          Date.new(y,m,d) rescue nil
        end
      when *TIMES
        if val.is_a?(Array)
          y, m, d, hh, mm, ss = *[val].flatten
          Time.zone.local(y, m, d, hh, mm, ss) rescue nil
        else
          unless val.acts_like?(:time)
            val = val.is_a?(String) ? Time.zone.parse(val) : val.to_time rescue val
          end
          val.in_time_zone rescue nil
        end
      when *BOOLEANS
        if val.is_a?(String) && val.blank?
          nil
        else
          TRUE_VALUES.include?(val)
        end
      when :integer
        val.blank? ? nil : val.to_i
      when :float
        val.blank? ? nil : val.to_f
      when :decimal
        if val.blank?
          nil
        elsif val.class == BigDecimal
          val
        elsif val.respond_to?(:to_d)
          val.to_d
        else
          val.to_s.to_d
        end
      else
        raise TypeCastError, "Unable to cast columns of type #{type}"
      end
    end

    def collapse_multiparameter_options(opts)
      opts.keys.each do |k|
        if k.include?("(")
          real_attribute, position = k.split(/\(|\)/)
          cast = %w(a s i).include?(position.last) ? position.last : nil
          position = position.to_i - 1
          value = opts.delete(k)
          opts[real_attribute] ||= []
          opts[real_attribute][position] = if cast
            (value.blank? && cast == 'i') ? nil : value.send("to_#{cast}")
          else
            value
          end
        end
      end
      opts
    end
  end
end