require 'helper'

class TestSearch < Test::Unit::TestCase
  
  context "A company search" do
    setup do
      @search = Company.search
    end
    
    should "have an association named developers" do
      assert @search.association(:developers)
    end
    
    should "have a column named name" do
      assert @search.column(:name)
    end
    
    context "excluding the developer association" do
      setup do
        @search = Company.search(:search_options => {:exclude_associations => :developers})
      end
      
      should "not have an association named developers" do
        assert_nil @search.association(:developers)
      end
      
      should "raise an error if we try to search on developers" do
        assert_raise NoMethodError do
          @search.developers_name_eq = 'Blah'
        end
      end
    end
    
    context "excluding the name attribute" do
      setup do
        @search = Company.search(:search_options => {:exclude_attributes => :name})
      end
      
      should "not have a column named name" do
        assert_nil @search.column(:name)
      end
      
      should "raise an error if we try to search on name" do
        assert_raise NoMethodError do
          @search.name_eq = 'Blah'
        end
      end
    end
    
    context "where name contains optical" do
      setup do
        @search.name_contains = 'optical'
      end
    
      should "return one result" do
        assert_equal 1, @search.all.size
      end
    
      should "return a company named Advanced Optical Solutions" do
        assert_contains @search.all, Company.where(:name => 'Advanced Optical Solutions').first
      end
    
      should "not return a company named Initech" do
        assert_does_not_contain @search.all, Company.where(:name => "Initech").first
      end
    end
  
    context "where developer name starts with Ernie" do
      setup do
        @search.developers_name_starts_with = 'Ernie'
      end
    
      should "return one result" do
        assert_equal 1, @search.all.size
      end
      
      should "return a company named Mission Data" do
        assert_contains @search.all, Company.where(:name => 'Mission Data').first
      end
    
      should "not return a company named Initech" do
        assert_does_not_contain @search.all, Company.where(:name => "Initech").first
      end
      
      context "and slackers salary is greater than $70k" do
        setup do
          @search.slackers_salary_gt = 70000
        end
        
        should "return no results" do
          assert_equal 0, @search.all.size
        end
        
        should "join developers twice" do
          assert @search.to_sql.match(/join "developers".*join "developers"/i)
        end
        
        should "alias the second join of developers" do
          assert @search.to_sql.match(/join "developers" "slackers_companies"/i)
        end
      end
    end
  end
  
  context "A developer search" do
    setup do
      @search = Developer.search
    end
    
    should "have an association named projects" do
      assert @search.association(:projects)
    end
    
    context "where developer is Bob-approved" do
      setup do
        @search.notes_note_equals = "A straight shooter with upper management written all over him."
      end
      
      should "return Peter Gibbons" do
        assert_contains @search.all, Developer.where(:name => 'Peter Gibbons').first
      end
    end
    
    context "where name ends with Miller" do
      setup do
        @search.name_ends_with = 'Miller'
      end
      
      should "return one result" do
        assert_equal 1, @search.all.size
      end
      
      should "return a developer named Ernie Miller" do
        assert_contains @search.all, Developer.where(:name => 'Ernie Miller').first
      end
    
      should "not return a developer named Herb Myers" do
        assert_does_not_contain @search.all, Developer.where(:name => "Herb Myers").first
      end
    end
    
    context "where project estimated hours are greater than or equal to 1000" do
      setup do
        @search.projects_estimated_hours_gte = 1000
      end
      
      should "return three results" do
        assert_equal 3, @search.all.size
      end
      
      should "return these developers" do
        assert_same_elements @search.all.collect {|d| d.name},
                             ['Peter Gibbons', 'Michael Bolton', 'Samir Nagheenanajar']
      end
    end
    
    context "where project estimated hours are greater than 1000" do
      setup do
        @search.projects_estimated_hours_gt = 1000
      end
      
      should "return no results" do
        assert_equal 0, @search.all.size
      end
    end
  end
  
  context "A data type search" do
    setup do
      @search = DataType.search
    end
    
    should "raise an error on a contains search against a boolean column" do
      assert_raise NoMethodError do
        @search.bln_contains = "true"
      end
    end
    
    context "where boolean column equals true" do
      setup do
        @search.bln_equals = true
      end
      
      should "return five results" do
        assert_equal 5, @search.all.size
      end
      
      should "contain no results with a false boolean column" do
        assert_does_not_contain @search.all.collect {|r| r.bln}, false
      end
    end
    
    context "where date column is Christmas 2009 by array" do
      setup do
        @search.dat_equals = [2009, 12, 25]
      end
      
      should "return one result" do
        assert_equal 1, @search.all.size
      end
      
      should "contain a result with Christmas 2009 as its date" do
        assert_equal Date.parse('2009/12/25'), @search.first.dat
      end
    end
    
    context "where date column is Christmas 2009 by Date object" do
      setup do
        @search.dat_equals = Date.new(2009, 12, 25)
      end
      
      should "return one result" do
        assert_equal 1, @search.all.size
      end
      
      should "contain a result with Christmas 2009 as its date" do
        assert_equal Date.parse('2009/12/25'), @search.first.dat
      end
    end
    
    context "where time column is > 1:00 PM and < 3:30 PM" do
      setup do
        @search.tim_gt = Time.parse('2000-01-01 13:00') # Rails "dummy time" format
        @search.tim_lt = Time.parse('2000-01-01 15:30') # Rails "dummy time" format
      end
      
      should "return three results" do
        assert_equal 3, @search.all.size
      end
      
      should "not contain results with time column before or after constraints" do
        assert_empty @search.all.select {|r|
          r.tim < Time.parse('2000-01-01 13:00') || r.tim > Time.parse('2000-01-01 15:30')
        }
      end
    end
    
    context "where timestamp column is in the year 2010" do
      setup do
        @search.tms_gte = Time.utc(2010, 1, 1)
      end
      
      should "return two results" do
        assert_equal 2, @search.all.size
      end
      
      should "not contain results with timestamp column before 2010" do
        assert_empty @search.all.select {|r|
          r.tms < Time.utc(2010, 1, 1)
        }
      end
    end
    
    context "where datetime column is before the year 2010" do
      setup do
        @search.tms_lt = Time.utc(2010, 1, 1)
      end
      
      should "return seven results" do
        assert_equal 7, @search.all.size
      end
      
      should "not contain results with timestamp in 2010" do
        assert_empty @search.all.select {|r|
          r.tms >= Time.utc(2010, 1, 1)
        }
      end
    end
    
    context "where decimal column is  > 5000" do
      setup do
        @search.dec_gt = 5000
      end
      
      should "return four results" do
        assert_equal 4, @search.all.size
      end
      
      should "not contain results with decimal column <= 5000" do
        assert_empty @search.all.select {|r|
          r.dec <= 5000
        }
      end
    end
    
    context "where float column is between 2.5 and 3.5" do
      setup do
        @search.flt_gte = 2.5
        @search.flt_lte = 3.5
      end
      
      should "return three results" do
        assert_equal 3, @search.all.size
      end
      
      should "not contain results with float column outside constraints" do
        assert_empty @search.all.select {|r|
          r.flt < 2.5 || r.flt > 3.5
        }
      end
    end
    
    context "where integer column is in the set (1, 4, 387420489)" do
      setup do
        @search.int_in = [1, 8, 729]
        puts @search.to_sql
      end
      
      should "return three results" do
        assert_equal 3, @search.all.size
      end
      
      should "not contain results outside the specified set" do
        assert_empty @search.all.select {|r|
          ![1, 8, 729].include?(r.int)
        }
      end
    end
  end
end
