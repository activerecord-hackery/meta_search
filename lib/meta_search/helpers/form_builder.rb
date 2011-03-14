require 'action_view'
require 'action_view/template'
module MetaSearch
  Check = Struct.new(:box, :label)

  module Helpers
    module FormBuilder

      def self.included(base)
        # Only take on the check_boxes method names if someone else (Hi, José!) hasn't grabbed them.
        alias_method :check_boxes, :checks unless base.method_defined?(:check_boxes)
        alias_method :collection_check_boxes, :collection_checks unless base.method_defined?(:collection_check_boxes)
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
      # generates <tt>MetaSearch::Check</tt>s. These consist of two attributes, +box+ and +label+,
      # which are (unsurprisingly) the HTML for the check box and the label. Called without a block,
      # this method will return an array of check boxes. Called with a block, it will yield each
      # check box to your template.
      #
      # *Parameters:*
      #
      # * +method+ - The method name on the form_for object
      # * +choices+ - An array of arrays, the first value in each element is the text for the
      #   label, and the last is the value for the checkbox
      # * +options+ - An options hash to be passed through to the checkboxes
      #
      # *Examples:*
      #
      # <b>Simple formatting:</b>
      #
      #   <h4>How many heads?</h4>
      #   <ul>
      #     <% f.checks :number_of_heads_in,
      #        [['One', 1], ['Two', 2], ['Three', 3]], :class => 'checkboxy' do |check| %>
      #        <li>
      #          <%= check.box %>
      #          <%= check.label %>
      #        </li>
      #     <% end %>
      #   </ul>
      #
      # This example will output the checkboxes and labels in an unordered list format.
      #
      # <b>Grouping:</b>
      #
      # Chain <tt>in_groups_of(<num>, false)</tt> on checks like so:
      #   <h4>How many heads?</h4>
      #   <p>
      #     <% f.checks(:number_of_heads_in,
      #        [['One', 1], ['Two', 2], ['Three', 3]],
      #        :class => 'checkboxy').in_groups_of(2, false) do |checks| %>
      #       <% checks.each do |check| %>
      #         <%= check.box %>
      #         <%= check.label %>
      #       <% end %>
      #       <br />
      #     <% end %>
      #   </p>
      def checks(method, choices = [], options = {}, &block)
        unless choices.first.respond_to?(:first) && choices.first.respond_to?(:last)
          raise ArgumentError, 'invalid choice array specified'
        end
        collection_checks(method, choices, :last, :first, options, &block)
      end

      # Just like +checks+, but this time you can pass in a collection, value, and text method,
      # as with collection_select.
      #
      # Example:
      #
      #   <% f.collection_checks :head_sizes_in, HeadSize.all,
      #       :id, :name, :class => 'headcheck' do |check| %>
      #     <%= check.box %> <%= check.label %>
      #   <% end %>
      def collection_checks(method, collection, value_method, text_method, options = {}, &block)
        check_boxes = []
        collection.each do |choice|
          text = choice.send(text_method)
          value = choice.send(value_method)
          check = MetaSearch::Check.new
          check.box = @template.check_box_tag(
            "#{@object_name}[#{method}][]",
            value,
            [@object.send(method)].flatten.include?(value),
            options.merge(:id => [@object_name, method.to_s, value.to_s.underscore].join('_'))
          )
          check.label = @template.label_tag([@object_name, method.to_s, value.to_s.underscore].join('_'),
                                        text)
          if block_given?
            yield check
          else
            check_boxes << check
          end
        end
        check_boxes unless block_given?
      end

      # Creates a sort link for the MetaSearch::Builder the form is created against.
      # Useful shorthand if your results happen to reside in the context of your
      # form_for block.
      # Sample usage:
      #
      #   <%= f.sort_link :name %>
      #   <%= f.sort_link :name, 'Company Name' %>
      #   <%= f.sort_link :name, :class => 'name_sort' %>
      #   <%= f.sort_link :name, 'Company Name', :class => 'company_name_sort' %>
      def sort_link(attribute, *args)
        @template.sort_link @object, attribute, *args
      end

      private

      # If the last element of the arguments to multiparameter_field has no :field_type
      # key, we assume it's got some defaults to be used in the other hashes.
      def has_multiparameter_defaults?(args)
        args.size > 1 && args.last.is_a?(Hash) && !args.last.has_key?(:field_type)
      end
    end
  end
end