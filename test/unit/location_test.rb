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
  
  def test_outputs
    outputs = {}
    outputs[:to_h] = {:latitude=>32.8952, :city=>"San Diego", :state=>"California", :longitude=>117.2051, :radius=>50, :zip=>"92121", :everywhere=>false}
    outputs[:form_value] = "San Diego, California"
    outputs[:to_cookie] = "{\"latitude\": 32.8952, \"city\": \"San Diego\", \"state\": \"California\", \"longitude\": 117.2051, \"radius\": 50, \"zip\": \"92121\", \"everywhere\": false}"
    outputs[:display_value] = "near San Diego, California"
    loc = Location.new('92121')
    
    assert_equal loc.to_h, outputs[:to_h]
    assert_equal loc.form_value, outputs[:form_value]
    # assert_equal loc.to_cookie, outputs[:to_cookie]
    assert_equal loc.display_value, outputs[:display_value]
  end
  
end
