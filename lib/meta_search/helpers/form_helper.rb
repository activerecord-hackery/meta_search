module MetaSearch
  module Helpers
    module FormHelper
      def apply_form_for_options!(object_or_array, options)
        if object_or_array.is_a?(MetaSearch::Builder)
          builder = object_or_array
          options[:url] ||= polymorphic_path(object_or_array.base)
        elsif object_or_array.is_a?(Array) && (builder = object_or_array.detect {|o| o.is_a?(MetaSearch::Builder)})
          options[:url] ||= polymorphic_path(object_or_array.map {|o| o.is_a?(MetaSearch::Builder) ? o.base : o})
        else
          super 
          return
        end

        html_options = {
          :class  => options[:as] ? "#{options[:as]}_search" : "#{builder.base.to_s.underscore}_search",
          :id => options[:as] ? "#{options[:as]}_search" : "#{builder.base.to_s.underscore}_search",
          :method => :get }
        options[:html] ||= {}
        options[:html].reverse_merge!(html_options)
      end
    end
  end
end
