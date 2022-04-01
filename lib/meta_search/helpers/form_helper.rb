module MetaSearch
  module Helpers
    module FormHelper
      def apply_form_for_options!(record,object,options)
        if object.is_a?(MetaSearch::Builder)
          builder = object
          options[:url] ||= polymorphic_path(object.base)
        elsif object.is_a?(Array) && (builder = object.detect {|o| o.is_a?(MetaSearch::Builder)})
          options[:url] ||= polymorphic_path(object.map {|o| o.is_a?(MetaSearch::Builder) ? o.base : o})
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
