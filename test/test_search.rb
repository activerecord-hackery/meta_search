require 'helper'

class TestSearch < Test::Unit::TestCase

  context "A Company search where options[:user] = 'blocked'" do
    setup do
      @s = Company.search({}, :user => 'blocked')
    end

    should "not respond_to? a search against backwards_name" do
      assert !@s.respond_to?(:backwards_name), "The search responded to :backwards_name"
    end

    should "raise an error if we try to search on backwards_name" do
      assert_raise NoMethodError do
        @s.backwards_name = 'blah'
      end
    end

    should "not respond_to? a search against updated_at_eq" do
      assert !@s.respond_to?(:updated_at_eq), "The search responded to :updated_at_eq"
    end

    should "raise an error if we try to search on updated_at" do
      assert_raise NoMethodError do
        @s.updated_at_eq = 'blah'
      end
    end

    should "not respond_to? a search against notes_note_matches" do
      assert !@s.respond_to?(:notes_note_matches), "The search responded to :notes_note_matches"
    end

    should "raise an error if we try to search on notes_note_matches" do
      assert_raise NoMethodError do
        @s.notes_note_matches = '%blah%'
      end
    end
  end

  context "A Developer search where options[:user] = 'privileged'" do
    setup do
      @s = Developer.search({}, :user => 'privileged')
    end

    should "respond_to? a search against name_eq" do
      assert_respond_to @s, :name_eq
    end

    should "not raise an error on a search against name_eq" do
      assert_nothing_raised do
        @s.name_eq = 'blah'
      end
    end

    should "respond_to? a search against company_name_eq" do
      assert_respond_to @s, :company_name_eq
    end

    should "not raise an error on a search against name_eq" do
      assert_nothing_raised do
        @s.company_name_eq = 'blah'
      end
    end

    should "respond_to? a search against company_updated_at_eq" do
      assert_respond_to @s, :company_updated_at_eq
    end

    should "not raise an error on a search against company_updated_at_eq" do
      assert_nothing_raised do
        @s.company_updated_at_eq = Time.now
      end
    end
  end

  context "A Developer search" do
    setup do
      @s = Developer.search({:name_equals=>"Forgetful Notetaker"})
    end

    context "without any opts" do
      should "find a null entry when searching notes" do
        assert_equal 1, @s.notes_note_is_null(true).all.size
      end

      should "find no non-null entry when searching notes" do
        assert_equal 0, @s.notes_note_is_not_null(true).all.size
      end
    end

    context "with outer join specified" do
      setup do
        @s = Developer.search({:name_equals => "Forgetful Notetaker"}, :join_type => :outer)
      end

      should "find a null entry when searching notes" do
        assert_equal 1, @s.notes_note_is_null(true).all.size
      end

      should "find no non-null entry when searching notes" do
        assert_equal 0, @s.notes_note_is_not_null(true).all.size
      end
    end

    context "with inner join specified" do
      setup do
        @s = Developer.search({:name_equals=>"Forgetful Notetaker"}, :join_type => :inner)
      end

      should "find no null entry when searching notes" do
        assert_equal 0, @s.notes_note_is_null(true).all.size
      end

      should "find no non-null entry when searching notes" do
        assert_equal 0, @s.notes_note_is_not_null(true).all.size
      end
    end


  end

  [{:name => 'Company', :object => Company},
   {:name => 'Company as a Relation', :object => Company.scoped}].each do |object|
    context_a_search_against object[:name], object[:object] do
      should "have a relation attribute which is an ActiveRecord::Relation" do
        assert_equal ActiveRecord::Relation, @s.relation.class
      end

      should "have a base attribute which is a Class inheriting from ActiveRecord::Base" do
        assert_equal Company, @s.base
        assert_contains @s.base.ancestors, ActiveRecord::Base
      end

      should "have an association named developers" do
        assert @s.get_association(:developers)
      end

      should "respond_to? a search against a developer attribute" do
        assert_respond_to @s, :developers_name_eq
      end

      should "have a column named name" do
        assert @s.get_column(:name)
      end

      should "respond_to? a search against name" do
        assert_respond_to @s, :name_eq
      end

      should "respond_to? a search against backwards_name" do
        assert_respond_to @s, :backwards_name
      end

      should "exclude the column named updated_at" do
        assert_nil @s.get_column(:updated_at)
      end

      should "not respond_to? updated_at" do
        assert !@s.respond_to?(:updated_at), "The search responded to :updated_at"
      end

      should "raise an error if we try to search on updated_at" do
        assert_raise NoMethodError do
          @s.updated_at_eq = [2009, 1, 1]
        end
      end

      should "exclude the association named notes" do
        assert_nil @s.get_association(:notes)
      end

      should "not respond_to? notes_note_eq" do
        assert !@s.respond_to?(:notes_note_eq), "The search responded to :notes_note_eq"
      end

      should "raise an error if we try to search on notes" do
        assert_raise NoMethodError do
          @s.notes_note_eq = 'Blah'
        end
      end

      should "honor its associations' excluded attributes" do
        assert_nil @s.get_attribute(:data_types_str)
      end

      should "not respond_to? data_types_str_eq" do
        assert !@s.respond_to?(:data_types_str_eq), "The search responded to :data_types_str_eq"
      end

      should "respond_to? data_types_bln_eq" do
        assert_respond_to @s, :data_types_bln_eq
      end

      should "raise an error if we try to search data_types.str" do
        assert_raise NoMethodError do
          @s.data_types_str_eq = 'Blah'
        end
      end

      should "raise an error when MAX_JOIN_DEPTH is exceeded" do
        assert_raise MetaSearch::JoinDepthError do
          @s.developers_company_developers_company_developers_name_equals = "Ernie Miller"
        end
      end

      context "when meta_sort value is empty string" do
        setup do
          @s.meta_sort = ''
        end

        should "not raise an error, just ignore sorting" do
          assert_nothing_raised do
            assert_equal Company.all, @s.all
          end
        end
      end

      should "sort by name in ascending order" do
        @s.meta_sort = 'name.asc'
        assert_equal Company.order('name asc').all,
                     @s.all
      end

      should "sort by name in ascending order as a method call" do
        @s.meta_sort 'name.asc'
        assert_equal Company.order('name asc').all,
                     @s.all
      end

      should "sort by name in descending order" do
        @s.meta_sort = 'name.desc'
        assert_equal Company.order('name desc').all,
                     @s.all
      end

      context "where name contains optical" do
        setup do
          @s.name_contains = 'optical'
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "return a company named Advanced Optical Solutions" do
          assert_contains @s.all, Company.where(:name => 'Advanced Optical Solutions').first
        end

        should "not return a company named Initech" do
          assert_does_not_contain @s.all, Company.where(:name => "Initech").first
        end
      end

      context "where name contains optical as a method call" do
        setup do
          @s.name_contains 'optical'
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "return a company named Advanced Optical Solutions" do
          assert_contains @s.all, Company.where(:name => 'Advanced Optical Solutions').first
        end

        should "not return a company named Initech" do
          assert_does_not_contain @s.all, Company.where(:name => "Initech").first
        end
      end

      context "where developer name starts with Ernie" do
        setup do
          @s.developers_name_starts_with = 'Ernie'
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "return a company named Mission Data" do
          assert_contains @s.all, Company.where(:name => 'Mission Data').first
        end

        should "not return a company named Initech" do
          assert_does_not_contain @s.all, Company.where(:name => "Initech").first
        end

        context "and slackers salary is greater than $70k" do
          setup do
            @s.slackers_salary_gt = 70000
          end

          should "return no results" do
            assert_equal 0, @s.all.size
          end

          should "join developers twice" do
            assert @s.to_sql.match(/join\s+"?developers"?.*join\s+"?developers"?/i)
          end

          should "alias the second join of developers" do
            assert @s.to_sql.match(/join\s+"?developers"?\s+"?slackers_companies"?/i)
          end
        end
      end

      context "where developer note indicates he will crack yo skull" do
        setup do
          @s.developer_notes_note_equals = "Will show you what he's doing."
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "return a company named Advanced Optical Solutions" do
          assert_contains @s.all, Company.where(:name => 'Advanced Optical Solutions').first
        end

        should "not return a company named Mission Data" do
          assert_does_not_contain @s.all, Company.where(:name => "Mission Data").first
        end
      end

      context "where developer note indicates he will crack yo skull through two associations" do
        setup do
          @s.developers_notes_note_equals = "Will show you what he's doing."
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "return a company named Advanced Optical Solutions" do
          assert_contains @s.all, Company.where(:name => 'Advanced Optical Solutions').first
        end

        should "not return a company named Mission Data" do
          assert_does_not_contain @s.all, Company.where(:name => "Mission Data").first
        end
      end

      context "where developer note indicates he will crack yo skull through four associations" do
        setup do
          @s.developers_company_developers_notes_note_equals = "Will show you what he's doing."
        end

        should "return two results, one of which is a duplicate due to joins" do
          assert_equal 2, @s.all.size
          assert_equal 1, @s.all.uniq.size
        end

        should "return a company named Advanced Optical Solutions" do
          assert_contains @s.all, Company.where(:name => 'Advanced Optical Solutions').first
        end

        should "not return a company named Mission Data" do
          assert_does_not_contain @s.all, Company.where(:name => "Mission Data").first
        end
      end

      context "where backwards name is hcetinI as a method call" do
        setup do
          @s.backwards_name 'hcetinI'
        end

        should "return 1 result" do
          assert_equal 1, @s.all.size
        end

        should "return a company named Initech" do
          assert_contains @s.all, Company.where(:name => 'Initech').first
        end
      end

      context "where backwards name is hcetinI" do
        setup do
          @s.backwards_name = 'hcetinI'
        end

        should "return 1 result" do
          assert_equal 1, @s.all.size
        end

        should "return a company named Initech" do
          assert_contains @s.all, Company.where(:name => 'Initech').first
        end
      end

      context "where with_slackers_by_name_and_salary_range is sent an array with 3 values" do
        setup do
          @s.with_slackers_by_name_and_salary_range = ['Peter Gibbons', 90000, 110000]
        end

        should "return 1 result" do
          assert_equal 1, @s.all.size
        end

        should "return a company named Initech" do
          assert_contains @s.all, Company.where(:name => 'Initech').first
        end
      end

      should "raise an error when the wrong number of parameters would be supplied to a custom search" do
        assert_raise ArgumentError do
          @s.with_slackers_by_name_and_salary_range = ['Peter Gibbons', 90000]
        end
      end

      should "raise an error when a custom search method does not return a relation" do
        assert_raise MetaSearch::NonRelationReturnedError do
          @s.backwards_name_as_string = 'hcetinI'
        end
      end
    end
  end

  [{:name => 'Developer', :object => Developer},
   {:name => 'Developer as a Relation', :object => Developer.scoped}].each do |object|
    context_a_search_against object[:name], object[:object] do
      should "exclude the column named company_id" do
        assert_nil @s.get_column(:company_id)
      end

      should "have an association named projects" do
        assert @s.get_association(:projects)
      end

      context "sorted by company name in ascending order" do
        setup do
          @s.meta_sort = 'company_name.asc'
        end

        should "sort by company name in ascending order" do
          assert_equal Developer.joins(:company).order('companies.name asc').all,
                       @s.all
        end
      end

      context "sorted by company name in descending order" do
        setup do
          @s.meta_sort = 'company_name.desc'
        end

        should "sort by company name in descending order" do
          assert_equal Developer.joins(:company).order('companies.name desc').all,
                       @s.all
        end
      end

      context "sorted by salary and name in descending order" do
        setup do
          @s.meta_sort = 'salary_and_name.desc'
        end

        should "sort by salary and name in descending order" do
          assert_equal Developer.order('salary DESC, name DESC').all,
                       @s.all
        end
      end

      context "where developer is Bob-approved" do
        setup do
          @s.notes_note_equals = "A straight shooter with upper management written all over him."
        end

        should "return Peter Gibbons" do
          assert_contains @s.all, Developer.where(:name => 'Peter Gibbons').first
        end
      end

      context "where name or company name starts with m" do
        setup do
          @s.name_or_company_name_starts_with = "m"
        end

        should "return Michael Bolton and all employees of Mission Data" do
          assert_equal @s.all, Developer.where(:name => 'Michael Bolton').all +
                               Company.where(:name => 'Mission Data').first.developers
        end
      end

      context "where name ends with Miller" do
        setup do
          @s.name_ends_with = 'Miller'
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "return a developer named Ernie Miller" do
          assert_contains @s.all, Developer.where(:name => 'Ernie Miller').first
        end

        should "not return a developer named Herb Myers" do
          assert_does_not_contain @s.all, Developer.where(:name => "Herb Myers").first
        end
      end

      context "where name starts with any of Ernie, Herb, or Peter" do
        setup do
          @s.name_starts_with_any = ['Ernie', 'Herb', 'Peter']
        end

        should "return three results" do
          assert_equal 3, @s.all.size
        end

        should "return a developer named Ernie Miller" do
          assert_contains @s.all, Developer.where(:name => 'Ernie Miller').first
        end

        should "not return a developer named Samir Nagheenanajar" do
          assert_does_not_contain @s.all, Developer.where(:name => "Samir Nagheenanajar").first
        end
      end

      context "where name does not equal Ernie Miller" do
        setup do
          @s.name_ne = 'Ernie Miller'
        end

        should "return eight results" do
          assert_equal 8, @s.all.size
        end

        should "not return a developer named Ernie Miller" do
          assert_does_not_contain @s.all, Developer.where(:name => "Ernie Miller").first
        end
      end

      context "where name contains all of a, e, and i" do
        setup do
          @s.name_contains_all = ['a', 'e', 'i']
        end

        should "return two results" do
          assert_equal 2, @s.all.size
        end

        should "return a developer named Samir Nagheenanajar" do
          assert_contains @s.all, Developer.where(:name => "Samir Nagheenanajar").first
        end

        should "not return a developer named Ernie Miller" do
          assert_does_not_contain @s.all, Developer.where(:name => 'Ernie Miller').first
        end
      end

      context "where project estimated hours are greater than or equal to 1000" do
        setup do
          @s.projects_estimated_hours_gte = 1000
        end

        should "return three results" do
          assert_equal 3, @s.all.size
        end

        should "return these developers" do
          assert_same_elements @s.all.collect {|d| d.name},
                               ['Peter Gibbons', 'Michael Bolton', 'Samir Nagheenanajar']
        end
      end

      context "where project estimated hours are greater than 1000" do
        setup do
          @s.projects_estimated_hours_gt = 1000
        end

        should "return no results" do
          assert_equal 0, @s.all.size
        end
      end

      context "where developer is named Ernie Miller by polymorphic belongs_to against an association" do
        setup do
          @s.notes_notable_developer_type_name_equals = "Ernie Miller"
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "return a developer named Ernie Miller" do
          assert_contains @s.all, Developer.where(:name => 'Ernie Miller').first
        end

        should "not return a developer named Herb Myers" do
          assert_does_not_contain @s.all, Developer.where(:name => "Herb Myers").first
        end
      end
    end
  end

  [{:name => 'DataType', :object => DataType},
   {:name => 'DataType as a Relation', :object => DataType.scoped}].each do |object|
    context_a_search_against object[:name], object[:object] do
      should "raise an error on a contains search against a boolean column" do
        assert_raise NoMethodError do
          @s.bln_contains = "true"
        end
      end

      context "where boolean column equals true" do
        setup do
          @s.bln_equals = true
        end

        should "return five results" do
          assert_equal 5, @s.all.size
        end

        should "contain no results with a false boolean column" do
          assert_does_not_contain @s.all.collect {|r| r.bln}, false
        end
      end

      context "where boolean column is_true" do
        setup do
          @s.bln_is_true = true
        end

        should "return five results" do
          assert_equal 5, @s.all.size
        end

        should "contain no results with a false boolean column" do
          assert_does_not_contain @s.all.collect {|r| r.bln}, false
        end
      end

      context "where boolean column equals false" do
        setup do
          @s.bln_equals = false
        end

        should "return four results" do
          assert_equal 4, @s.all.size
        end

        should "contain no results with a true boolean column" do
          assert_does_not_contain @s.all.collect {|r| r.bln}, true
        end
      end

      context "where boolean column is_false" do
        setup do
          @s.bln_is_false = true
        end

        should "return four results" do
          assert_equal 4, @s.all.size
        end

        should "contain no results with a true boolean column" do
          assert_does_not_contain @s.all.collect {|r| r.bln}, true
        end
      end

      context "where date column is Christmas 2009 by array" do
        setup do
          @s.dat_equals = [2009, 12, 25]
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "contain a result with Christmas 2009 as its date" do
          assert_equal Date.parse('2009/12/25'), @s.first.dat
        end
      end

      context "where date column is Christmas 2009 by Date object" do
        setup do
          @s.dat_equals = Date.new(2009, 12, 25)
        end

        should "return one result" do
          assert_equal 1, @s.all.size
        end

        should "contain a result with Christmas 2009 as its date" do
          assert_equal Date.parse('2009/12/25'), @s.first.dat
        end
      end

      context "where time column is > 1:00 PM and < 3:30 PM" do
        setup do
          @s.tim_gt = Time.parse('2000-01-01 13:00') # Rails "dummy time" format
          @s.tim_lt = Time.parse('2000-01-01 15:30') # Rails "dummy time" format
        end

        should "return three results" do
          assert_equal 3, @s.all.size
        end

        should "not contain results with time column before or after constraints" do
          assert_equal [], @s.all.select {|r|
            r.tim < Time.parse('2000-01-01 13:00') || r.tim > Time.parse('2000-01-01 15:30')
          }
        end
      end

      context "where timestamp column is in the year 2010" do
        setup do
          @s.tms_gte = Time.utc(2010, 1, 1)
        end

        should "return two results" do
          assert_equal 2, @s.all.size
        end

        should "not contain results with timestamp column before 2010" do
          assert_equal [], @s.all.select {|r|
            r.tms < Time.utc(2010, 1, 1)
          }
        end
      end

      context "where timestamp column is before the year 2010" do
        setup do
          @s.tms_lt = Time.utc(2010, 1, 1)
        end

        should "return seven results" do
          assert_equal 7, @s.all.size
        end

        should "not contain results with timestamp in 2010" do
          assert_equal [], @s.all.select {|r|
            r.tms >= Time.utc(2010, 1, 1)
          }
        end
      end

      context "where decimal column is  > 5000" do
        setup do
          @s.dec_gt = 5000
        end

        should "return four results" do
          assert_equal 4, @s.all.size
        end

        should "not contain results with decimal column <= 5000" do
          assert_equal [], @s.all.select {|r|
            r.dec <= 5000
          }
        end
      end

      context "where float column is between 2.5 and 3.5" do
        setup do
          @s.flt_gte = 2.5
          @s.flt_lte = 3.5
        end

        should "return three results" do
          assert_equal 3, @s.all.size
        end

        should "not contain results with float column outside constraints" do
          assert_equal [], @s.all.select {|r|
            r.flt < 2.5 || r.flt > 3.5
          }
        end
      end

      context "where integer column is in the set (1, 8, 729)" do
        setup do
          @s.int_in = [1, 8, 729]
        end

        should "return three results" do
          assert_equal 3, @s.all.size
        end

        should "not contain results outside the specified set" do
          assert_equal [], @s.all.select {|r|
            ![1, 8, 729].include?(r.int)
          }
        end
      end

      context "where integer column is not in the set (1, 8, 729)" do
        setup do
          @s.int_not_in = [1, 8, 729]
        end

        should "return six results" do
          assert_equal 6, @s.all.size
        end

        should "not contain results outside the specified set" do
          assert_equal [], @s.all.reject {|r|
            ![1, 8, 729].include?(r.int)
          }
        end
      end
    end
  end

  context_a_search_against "a relation with existing criteria and joins",
                           Company.where(:name => "Initech").joins(:developers) do
    should "return the same results as a non-searched relation with no search terms" do
      assert_equal Company.where(:name => "Initech").joins(:developers).all, @s.all
    end

    context "with a search against the joined association's data" do
      setup do
        @s.developers_salary_less_than = 75000
      end

      should "not ask to join the association twice" do
        assert_equal 1, @s.relation.joins_values.size
      end

      should "return a filtered result set based on the criteria of the searched relation" do
        assert_equal Company.where(:name => 'Initech').all, @s.all.uniq
      end
    end
  end

  context_a_search_against "a relation derived from a joined association",
                           Company.where(:name => "Initech").first.developers do
    should "not raise an error" do
      assert_nothing_raised do
        @s.all
      end
    end

    should "return all developers for that company without conditions" do
      assert_equal Company.where(:name => 'Initech').first.developers.all, @s.all
    end

    should "allow conditions on the search" do
      @s.name_equals = 'Peter Gibbons'
      assert_equal Developer.where(:name => 'Peter Gibbons').first,
                   @s.first
    end
  end

  context_a_search_against "a relation derived from a joined HM:T association",
                           Company.where(:name => "Initech").first.developer_notes do
    should "not raise an error" do
      assert_nothing_raised do
        @s.all
      end
    end

    should "return all developer notes for that company without conditions" do
      assert_equal Company.where(:name => 'Initech').first.developer_notes.all, @s.all
    end

    should "allow conditions on the search" do
      @s.note_equals = 'A straight shooter with upper management written all over him.'
      assert_equal Note.where(:note => 'A straight shooter with upper management written all over him.').first,
                   @s.first
    end
  end

  [{:name => 'Project', :object => Project},
   {:name => 'Project as a Relation', :object => Project.scoped}].each do |object|
    context_a_search_against object[:name], object[:object] do
      context "where name is present" do
        setup do
          @s.name_is_present = true
        end

        should "return 5 results" do
          assert_equal 5, @s.all.size
        end

        should "contain no results with a blank name column" do
          assert_equal 0, @s.all.select {|r| r.name.blank?}.size
        end
      end

      context "where name is blank" do
        setup do
          @s.name_is_blank = true
        end

        should "return 2 results" do
          assert_equal 2, @s.all.size
        end

        should "contain no results with a present name column" do
          assert_equal 0, @s.all.select {|r| r.name.present?}.size
        end
      end

      context "where name is null" do
        setup do
          @s.name_is_null = true
        end

        should "return 1 result" do
          assert_equal 1, @s.all.size
        end

        should "contain no results with a non-null name column" do
          assert_equal 0, @s.all.select {|r| r.name != nil}.size
        end
      end

      context "where name is not null" do
        setup do
          @s.name_is_not_null = true
        end

        should "return 6 results" do
          assert_equal 6, @s.all.size
        end

        should "contain no results with a null name column" do
          assert_equal 0, @s.all.select {|r| r.name = nil}.size
        end
      end

      context "where notes_id is null" do
        setup do
          @s.notes_id_is_null = true
        end

        should "return 2 results" do
          assert_equal 2, @s.all.size
        end

        should "contain no results with notes" do
          assert_equal 0, @s.all.select {|r| r.notes.size > 0}.size
        end
      end
    end
  end

  [{:name => 'Note', :object => Note},
   {:name => 'Note as a Relation', :object => Note.scoped}].each do |object|
    context_a_search_against object[:name], object[:object] do
      should "allow search on polymorphic belongs_to associations" do
        @s.notable_project_type_name_contains = 'MetaSearch'
        assert_equal Project.find_by_name('MetaSearch Development').notes, @s.all
      end

      should "allow search on multiple polymorphic belongs_to associations" do
        @s.notable_project_type_name_or_notable_developer_type_name_starts_with = 'M'
        assert_equal Project.find_by_name('MetaSearch Development').notes +
                     Developer.find_by_name('Michael Bolton').notes,
                     @s.all
      end

      should "allow traversal of polymorphic associations" do
        @s.notable_developer_type_company_name_starts_with = 'M'
        assert_equal Company.find_by_name('Mission Data').developers.map(&:notes).flatten.sort {|a, b| a.id <=>b.id},
                     @s.all.sort {|a, b| a.id <=> b.id}
      end

      should "raise an error when attempting to search against polymorphic belongs_to association without a type" do
        assert_raises ::MetaSearch::PolymorphicAssociationMissingTypeError do
          @s.notable_name_contains = 'MetaSearch'
        end
      end
    end
  end
end
