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
  
  context "A form using check_boxes with three choices" do
    setup do
      @s = Company.search
      fields_for :search, @s do |f|
        @f = f
      end
    end
    
    should "generate the expected HTML without a block" do
      assert_dom_equal '<input id="search_id_in_1" name="search[id_in][]" ' +
                       'type="checkbox" value="1" /><label for="search_id_in_1">One</label>' +
                       '<input id="search_id_in_2" name="search[id_in][]" ' +
                       'type="checkbox" value="2" /><label for="search_id_in_2">Two</label>' +
                       '<input id="search_id_in_3" name="search[id_in][]" ' +
                       'type="checkbox" value="3" /><label for="search_id_in_3">Three</label>',
                       @f.check_boxes(:id_in, [['One', 1], ['Two', 2], ['Three', 3]])
    end
    
    should "generate the expected HTML with a block" do
      @f.check_boxes(:id_in, [['One', 1], ['Two', 2], ['Three', 3]]) do |c|
        concat render :to => :string, :inline => "<p><%= c[:label] %> <%= c[:check_box] %></p>", :locals => {:c => c}
      end
      assert_dom_equal output_buffer,
                      '<p><label for="search_id_in_1">One</label> ' +
                      '<input id="search_id_in_1" name="search[id_in][]" ' +
                      'type="checkbox" value="1" /></p>' +
                      '<p><label for="search_id_in_2">Two</label> ' +
                      '<input id="search_id_in_2" name="search[id_in][]" ' +
                      'type="checkbox" value="2" /></p>' +
                      '<p><label for="search_id_in_3">Three</label> ' +
                      '<input id="search_id_in_3" name="search[id_in][]" ' +
                      'type="checkbox" value="3" /></p>'
    end
  end
  
  context "A form using check_boxes with three choices and a previous selection" do
    setup do
      @s = Company.search
      @s.id_in = [1, 3]
      fields_for :search, @s do |f|
        @f = f
      end
    end
    
    should "generate the expected HTML without a block" do
      assert_dom_equal '<input checked="checked" id="search_id_in_1" name="search[id_in][]" ' +
                       'type="checkbox" value="1" /><label for="search_id_in_1">One</label>' +
                       '<input id="search_id_in_2" name="search[id_in][]" ' +
                       'type="checkbox" value="2" /><label for="search_id_in_2">Two</label>' +
                       '<input checked="checked" id="search_id_in_3" name="search[id_in][]" ' +
                       'type="checkbox" value="3" /><label for="search_id_in_3">Three</label>',
                       @f.check_boxes(:id_in, [['One', 1], ['Two', 2], ['Three', 3]])
    end
    
    should "generate the expected HTML with a block" do
      @f.check_boxes(:id_in, [['One', 1], ['Two', 2], ['Three', 3]]) do |c|
        concat render :to => :string, :inline => "<p><%= c[:label] %> <%= c[:check_box] %></p>", :locals => {:c => c}
      end
      assert_dom_equal output_buffer,
                       '<p><label for="search_id_in_1">One</label> <input checked="checked" id="search_id_in_1" ' +
                       'name="search[id_in][]" type="checkbox" value="1" /></p><p><label for="search_id_in_2">' +
                       'Two</label> <input id="search_id_in_2" name="search[id_in][]" type="checkbox" value="2" />' +
                       '</p><p><label for="search_id_in_3">Three</label> <input checked="checked" id="search_id_in_3" ' +
                       'name="search[id_in][]" type="checkbox" value="3" /></p>'
    end
    
    context "A form using collection_check_boxes with companies" do
      setup do
        @s = Company.search
        fields_for :search, @s do |f|
          @f = f
        end
      end
      
      should "generate the expected HTML without a block" do
        assert_dom_equal '<input id="search_id_in_1" name="search[id_in][]" type="checkbox" ' +
                         'value="1" /><label for="search_id_in_1">Initech</label>' +
                         '<input id="search_id_in_2" name="search[id_in][]" type="checkbox" ' +
                         'value="2" /><label for="search_id_in_2">Advanced Optical Solutions</label>' +
                         '<input id="search_id_in_3" name="search[id_in][]" type="checkbox" ' +
                         'value="3" /><label for="search_id_in_3">Mission Data</label>',
                         @f.collection_check_boxes(:id_in, Company.all, :id, :name)
      end
      
      should "generate the expected HTML with a block" do
        @f.collection_check_boxes(:id_in, Company.all, :id, :name) do |c|
          concat render :to => :string, :inline => "<p><%= c[:label] %> <%= c[:check_box] %></p>", :locals => {:c => c}
        end
        assert_dom_equal output_buffer,
                         '<p><label for="search_id_in_1">Initech</label> ' +
                         '<input id="search_id_in_1" name="search[id_in][]" type="checkbox" value="1" /></p>' +
                         '<p><label for="search_id_in_2">Advanced Optical Solutions</label> ' +
                         '<input id="search_id_in_2" name="search[id_in][]" type="checkbox" value="2" /></p>' +
                         '<p><label for="search_id_in_3">Mission Data</label> ' +
                         '<input id="search_id_in_3" name="search[id_in][]" type="checkbox" value="3" /></p>'
      end
    end
  end
end