module MetaSearch
  module Helpers
    module UrlHelper
      
      def sort_link(builder, attribute, *args)
        raise ArgumentError, "Need a MetaSearch::Builder search object as first param!" unless builder.is_a?(MetaSearch::Builder)
        attr_name = attribute.to_s
        name = (args.size > 0 && !args.first.is_a?(Hash)) ? args.shift.to_s : attr_name.humanize
        prev_attr, prev_order = builder.search_attributes['meta_sort'].to_s.split('.')
        current_order = prev_attr == attr_name ? prev_order : nil
        new_order = current_order == 'asc' ? 'desc' : 'asc'
        options = args.first.is_a?(Hash) ? args.shift : {}
        html_options = args.first.is_a?(Hash) ? args.shift : {}
        css = ['sort_link', current_order].compact.join(' ')
        html_options[:class] = [css, html_options[:class]].compact.join(' ')
        options.merge!(
          'search' => builder.search_attributes.merge(
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