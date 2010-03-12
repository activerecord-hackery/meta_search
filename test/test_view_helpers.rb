require 'helper'
require 'action_controller'
require 'action_view/test_case'

class TestViewHelpers < ActionView::TestCase
  tests ActionView::Helpers::FormHelper
  
  context "A previously-filled search form" do
    setup do
      @s = Company.search
      @s.created_at_gte = [2001, 2, 3, 4, 5]
      @s.name_contains = "bacon"
      fields_for :search, @s do |f|
        @f = f
      end
    end

    should "retain previous search terms" do
      html = @f.datetime_select(:created_at_gte)
      ['2001', '3', '04', '05'].each do |v|
        assert_match /<option selected="selected" value="#{v}">#{v}<\/option>/,
                     html
      end
      assert_match /<option selected="selected" value="2">February<\/option>/, html
      assert_dom_equal '<input id="search_name_contains" name="search[name_contains]" ' +
                       'size="30" type="text" value="bacon" />',
                        @f.text_field(:name_contains)
    end
  end
  
  context "A form using mutiparameter_field with default size option" do
    setup do
      @s = Developer.search
      fields_for :search, @s do |f|
        @f = f
      end
    end
    
    should "apply proper cast and default size attribute to text fields" do
      html = @f.multiparameter_field :salary_in, 
             {:field_type => :text_field, :type_cast => 'i'},
             {:field_type => :text_field, :type_cast => 'i'}, :size => 10
      assert_dom_equal '<input id="search_salary_in(1i)" name="search[salary_in(1i)]" ' +
                       'size="10" type="text" />' +
                       '<input id="search_salary_in(2i)" name="search[salary_in(2i)]" ' +
                       'size="10" type="text" />',
                       html
    end
  end
end