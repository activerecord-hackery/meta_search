module MetaSearch
  module Helpers
    module UrlHelper

      # Generates a column sort link for a given attribute of a MetaSearch::Builder object.
      # The link maintains existing options for the sort as parameters in the URL, and
      # sets a meta_sort parameter as well. If the first parameter after the attribute name
      # is not a hash, it will be used as a string for alternate link text. If a hash is
      # supplied, it will be passed to link_to as an html_options hash. The link will
      # be assigned two css classes: sort_link and one of "asc" or "desc", depending on
      # the current sort order. Any class supplied in the options hash will be appended.
      #
      # Sample usage:
      #
      #   <%= sort_link @search, :name %>
      #   <%= sort_link @search, :name, 'Company Name' %>
      #   <%= sort_link @search, :name, :class => 'name_sort' %>
      #   <%= sort_link @search, :name, 'Company Name', :class => 'company_name_sort' %>
      #   <%= sort_link @search, :name, :default_order => :desc %>
      #   <%= sort_link @search, :name, 'Company Name', :default_order => :desc %>
      #   <%= sort_link @search, :name, :class => 'name_sort', :default_order => :desc %>
      #   <%= sort_link @search, :name, 'Company Name', :class => 'company_name_sort', :default_order => :desc %>

      def sort_link(builder, attribute, *args)
        raise ArgumentError, "Need a MetaSearch::Builder search object as first param!" unless builder.is_a?(MetaSearch::Builder)
        attr_name = attribute.to_s
        name = (args.size > 0 && !args.first.is_a?(Hash)) ? args.shift.to_s : builder.base.human_attribute_name(attr_name)
        prev_attr, prev_order = builder.search_attributes['meta_sort'].to_s.split('.')

        options = args.first.is_a?(Hash) ? args.shift.dup : {}
        current_order = prev_attr == attr_name ? prev_order : nil

        if options[:default_order] == :desc
          new_order = current_order == 'desc' ? 'asc' : 'desc'
        else
          new_order = current_order == 'asc' ? 'desc' : 'asc'
        end
        options.delete(:default_order)

        html_options = args.first.is_a?(Hash) ? args.shift : {}
        css = ['sort_link', current_order].compact.join(' ')
        html_options[:class] = [css, html_options[:class]].compact.join(' ')
        options.merge!(
          builder.search_key => builder.search_attributes.merge(
            'meta_sort' => [attr_name, new_order].join('.')
          )
        )
        link_to [ERB::Util.h(name), order_indicator_for(current_order)].compact.join(' ').html_safe,
                url_for(options),
                html_options
      end

      private

      def order_indicator_for(order)
        if order == 'asc'
          '&#9650;'
        elsif order == 'desc'
          '&#9660;'
        else
          nil
        end
      end
    end
  end
end
