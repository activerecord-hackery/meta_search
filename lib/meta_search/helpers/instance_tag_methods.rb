module MetaSearch
  module Helpers
    module InstanceTagMethods
      def to_label_tag(text = nil, options = {}, &block)
        if object && object.is_a?(MetaSearch::Builder)
          inject_metasearch_base { super }
        else
          super
        end
      end

      private

      def inject_metasearch_base
        orig_method_name = @method_name
        @method_name = "base{#{object.base}}#{@method_name}"

        result = yield

        @method_name = orig_method_name

        result
      end
    end
  end
end