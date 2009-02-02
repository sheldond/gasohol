require 'test_helper'

class OverrideTest < ActiveSupport::TestCase
  
  def test_fixtures
    assert_equal Override.find_by_keywords('running'), overrides(:running)
  end
  
  def test_single_word_lookups
    assert_equal Override.search('running'), overrides(:running)
    assert_equal Override.search('marathon'), overrides(:marathon)
    assert Override.search('asdf').nil?
  end
  
  def test_multi_word_lookups
    assert_equal Override.search('half marathon'), overrides(:half_marathon)
    assert_equal Override.search('marathon half'), overrides(:marathon)
    assert Override.search('john doe').nil?
  end
  
  def test_complex_lookup
    assert_equal Override.search('la jolla marathon'), overrides(:marathon)
    assert_equal Override.search('running la jolla'), overrides(:running)
  end
  
  # if there are multiple matches and they're all the same length, sort alphabetically and use that one
  def test_complex_lookup_with_equal_length_matches
    assert_equal Override.search('running ironman'), overrides(:ironman)
    assert_equal Override.search('ironman running'), overrides(:ironman)
  end
  
  # test single word versus mutliple word matches (multiple word should win)
  def test_complex_lookup_with_multi_word_matches
    assert_equal Override.search('la jolla half marathon'), overrides(:half_marathon)
    assert_equal Override.search('half marathon la jolla'), overrides(:half_marathon)
    assert_equal Override.search('running half marathon'), overrides(:half_marathon)
    assert_equal Override.search('half marathon running'), overrides(:half_marathon)
    assert_equal Override.search('running marathon'), overrides(:marathon)
    assert_equal Override.search('marathon running'), overrides(:marathon)
  end
  
  # if there are mulitple multi-word matches, and they all contain the same number of spaces, sort alphabetically
  def test_complex_lookup_with_multi_word_matches_but_equal_length
    assert_equal Override.search('fun run half marathon'), overrides(:fun_run)
    assert_equal Override.search('half marathon fun run'), overrides(:fun_run)
  end
  
end
