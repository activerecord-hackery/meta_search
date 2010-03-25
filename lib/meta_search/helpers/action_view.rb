require 'action_view'

module MetaSearch::Helpers
  module FormBuilder
    def self.enable! #:nodoc:
      ::ActionView::Helpers::FormBuilder.class_eval do
        include FormBuilder
        self.field_helpers += ['multiparameter_field', 'check_boxes', 'collection_check_boxes']
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
    
    # Behaves almost exactly like the select method, but instead of generating a select tag,
    # generates checkboxes. Since these checkboxes are just a checkbox and label with no
    # additional formatting by default, this method can also take a block parameter.
    #
    # *Parameters:*
    #
    # * +method+ - The method name on the form_for object
    # * +choices+ - An array of arrays, the first value in each element is the text for the
    #   label, and the last is the value for the checkbox
    # * +options+ - An options hash to be passed through to the checkboxes
    #
    # If a block is supplied, rather than just rendering the checkboxes and labels, the block
    # will receive a hash with two keys, :check_box and :label
    #
    # *Examples:*
    #
    # Simple usage:
    #
    #   <%= f.check_boxes :number_of_heads_in,
    #       [['One', 1], ['Two', 2], ['Three', 3]], :class => 'checkboxy' %>
    #
    # This will result in three checkboxes, with the labels "One", "Two", and "Three", and
    # corresponding numeric values, which will be sent as an array to the :number_of_heads_in
    # attribute of the form_for object.
    #
    # Additional formatting:
    #
    #   <table>
    #     <th colspan="2">How many heads?</th>
    #     <% f.check_boxes :number_of_heads_in,
    #        [['One', 1], ['Two', 2], ['Three', 3]], :class => 'checkboxy' do |c| %>
    #        <tr>
    #          <td><%= c[:check_box] %></td>
    #          <td><%= c[:label] %></td>
    #        </tr>
    #     <% end %>
    #   </table>
    #
    # This example will output the checkboxes and labels in a tabular format. You get the idea.
    def check_boxes(method, choices = [], options = {}, &block)
      unless choices.first.respond_to?(:first) && choices.first.respond_to?(:last)
        raise ArgumentError, 'invalid choice array specified'
      end
      collection_check_boxes(method, choices, :last, :first, options, &block)
    end
    
    # Just like +check_boxes+, but this time you can pass in a collection, value, and text method,
    # as with collection_select.
    #
    # Example:
    #
    #    <%= f.collection_check_boxes :head_sizes_in, HeadSize.all,
    #        :id, :name, :class => 'head-check' %>
    def collection_check_boxes(method, collection, value_method, text_method, options = {}, &block)
      html = ''.html_safe
      collection.each do |choice|
        text = choice.send(text_method)
        value = choice.send(value_method)
        c = {}
        c[:check_box] = @template.check_box_tag(
          "#{@object_name}[#{method}][]",
          value,
          [@object.send(method)].flatten.include?(value),
          options.merge(:id => [@object_name, method.to_s, value.to_s.underscore].join('_'))
        )
        c[:label] = @template.label_tag([@object_name, method.to_s, value.to_s.underscore].join('_'),
                                        text)
        yield c if block_given?
        html.safe_concat(c[:check_box] + c[:label])
      end
      html unless block_given?
    end
    
    private
    
    # If the last element of the arguments to multiparameter_field has no :field_type
    # key, we assume it's got some defaults to be used in the other hashes.
    def has_multiparameter_defaults?(args)
      args.size > 1 && args.last.is_a?(Hash) && !args.last.has_key?(:field_type)
    end
  end
end