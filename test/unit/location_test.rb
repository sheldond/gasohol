require 'test_helper'

class LocationTest < ActiveSupport::TestCase
  
  def test_parse_state_abbreviation
    assert Location.new('ca')
    assert Location.new('CA')
    assert Location.new(' ca')
    
    # invalid abbreviation
    assert_raise(Exceptions::LocationError::InvalidLocation) { Location.new('aa') }
  end
  
  def test_parse_state_name
    assert Location.new('california')
    assert Location.new('California')
    assert Location.new(' California')
    
    # invalid abbreviation
    assert_raise(Exceptions::LocationError::InvalidLocation) { Location.new('sausage') }
  end
  
  def test_parse_zip
    assert Location.new('92121')
    assert Location.new(' 92121')
    
    # invalid abbreviation
    assert_raise(Exceptions::LocationError::InvalidZip) { Location.new('0123') }
  end
  
  def test_parse_city_state
    assert Location.new('san diego, ca')
    assert Location.new('san diego,ca')
    assert Location.new(' san diego , ca')
    assert Location.new('San Diego, CA')
    assert Location.new('san diego, california')
    assert Location.new('San DIEGO,California')
    
    # assert Location.new('Cardiff by the Sea, ca')     # broken because of capitalization
    
    # invalid abbreviation
    assert_raise(Exceptions::LocationError::InvalidCityState) { Location.new('asdf, ca') }
  end
  
  def test_parse_everywhere
    assert Location.new('everywhere')
    assert Location.new('anywhere')
    assert Location.new('any')
    assert Location.new(' any ')
    
    # invalid abbreviation
    assert_raise(Exceptions::LocationError::InvalidLocation) { Location.new('every') }
  end
  
  def test_location_types_and_questions
    state = Location.new('ca')
    city_state = Location.new('San Diego, CA')
    zip = Location.new('92121')
    everywhere = Location.new('everywhere')
    
    assert_equal state.type, :only_state
    assert_equal state.only_state?, true
    assert_equal state.city_state?, false
    assert_equal state.everywhere?, false
    
    assert_equal city_state.type, :city_state
    assert_equal city_state.only_state?, false
    assert_equal city_state.city_state?, true
    assert_equal city_state.everywhere?, false
    
    assert_equal zip.type, :city_state
    assert_equal zip.only_state?, false
    assert_equal zip.city_state?, true
    assert_equal zip.everywhere?, false
    
    assert_equal everywhere.type, :everywhere
    assert_equal everywhere.only_state?, false
    assert_equal everywhere.city_state?, false
    assert_equal everywhere.everywhere?, true
  end
  
  def test_new_bang
    valid_location = Location.new!('San Diego, CA')
    invalid_location = Location.new!('asdf')
    
    assert valid_location
    assert invalid_location
    assert_equal invalid_location.everywhere?, true
  end
  
  def test_outputs
    outputs = {}
    outputs[:to_h] = {:latitude=>32.8952, :city=>"San Diego", :state=> { :name => "California", :abbreviation => "ca" }, :longitude=>117.2051, :radius=>50, :zip=>"92121", :everywhere=>false}
    outputs[:form_value] = "San Diego, California"
    outputs[:to_cookie] = "{\"latitude\": 32.8952, \"city\": \"San Diego\", \"state\": \"California\", \"longitude\": 117.2051, \"radius\": 50, \"zip\": \"92121\", \"everywhere\": false}"
    outputs[:display_value] = "near <strong>San Diego, California</strong>"
    loc = Location.new('92121')
    
    assert_equal loc.to_h, outputs[:to_h]
    assert_equal loc.form_value, outputs[:form_value]
    # assert_equal loc.to_cookie, outputs[:to_cookie]
    assert_equal loc.display_value, outputs[:display_value]
  end
  
end
