require 'action_view'

module MetaSearch::Helpers
  module FormBuilder
    
    def self.enable! #:nodoc:
      ::ActionView::Helpers::FormBuilder.class_eval do
        include FormBuilder
        self.field_helpers += ['multiparameter_field']
      end
    end
    
    # Like other form_for field methods (text_field, hidden_field, password_field) etc,
    # but takes a list of hashes between the +method+ parameter and the trailing option hash,
    # if any, to specify a number of fields to create in multiparameter fashion.
    #
    # Each hash *must* contain a :field_type option, which specifies a form_for method, and
    # _may_ contain an optional :type_cast option, with one of the typical multiparameter
    # type cast characters. Any remaining options will be merged with the defaults specified
    # in the trailing option hash and passed along when creating that field.
    #
    # For example...
    #
    #   <%= f.multiparameter_field :moderations_value_between,
    #       {:field_type => :text_field, :class => 'first'},
    #       {:field_type => :text_field, :type_cast => 'i'},
    #       :size => 5 %>
    #
    # ...will create the following HTML:
    #
    #   <input class="first" id="search_moderations_value_between(1)"
    #    name="search[moderations_value_between(1)]" size="5" type="text" />
    #
    #   <input id="search_moderations_value_between(2i)"
    #    name="search[moderations_value_between(2i)]" size="5" type="text" />
    #
    # As with any multiparameter input fields, these will be concatenated into an
    # array and passed to the attribute named by the first parameter for assignment.
    def multiparameter_field(method, *args)
      defaults = has_multiparameter_defaults?(args) ? args.pop : {}
      raise ArgumentError, "No multiparameter fields specified" if args.blank?
      html = ''.html_safe
      args.each_with_index do |field, index|
        type = field.delete(:field_type) || raise(ArgumentError, "No :field_type specified.")
        cast = field.delete(:type_cast) || ''
        opts = defaults.merge(field)
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
    
    private
    
    # If the last element of the arguments to multiparameter_field has no :field_type
    # key, we assume it's got some defaults to be used in the other hashes.
    def has_multiparameter_defaults?(args)
      args.size > 1 && args.last.is_a?(Hash) && !args.last.has_key?(:field_type)
    end
  end
end