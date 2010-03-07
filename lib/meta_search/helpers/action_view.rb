require 'action_view'

module MetaSearch::Helpers
  module FormBuilder
    
    def self.enable!
      ::ActionView::Helpers::FormBuilder.class_eval do
        include FormBuilder
        self.field_helpers += ['multiparameter_field']
      end
    end
    
    def multiparameter_field(method, fields_with_options)
      html = ''.html_safe
      fields_with_options.each_with_index do |field, index|
        type = field.delete(:field_type) || raise(ArgumentError, "No :field_type specified.")
        cast = field.delete(:type_cast) || ''
        opts = options.merge(field)
        html.safe_concat(
          @template.send(
            type.to_s,
            @object_name,
            (method.to_s + "(#{index + 1}#{cast})"),
            objectify_options(opts))
          )
      end
      html
    end
  end
end