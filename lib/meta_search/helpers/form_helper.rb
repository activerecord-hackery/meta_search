module MetaSearch
  module Helpers
    module FormHelper
      def apply_form_for_options!(object_or_array, options)
        if object_or_array.is_a?(Array) && object_or_array.first.is_a?(MetaSearch::Builder)
          builder = object_or_array.first
          html_options = {
            :class  => options[:as] ? "#{options[:as]}_search" : "#{builder.base.to_s.underscore}_search",
            :id => options[:as] ? "#{options[:as]}_search" : "#{builder.base.to_s.underscore}_search",
            :method => :get }
          options[:html] ||= {}
          options[:html].reverse_merge!(html_options)
          options[:url] ||= polymorphic_path(builder.base)
        else
          super
        end
      end
    end
  end
end