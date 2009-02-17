require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'cgi'
require 'chronic'
require 'logger'

require 'gasohol/search'
require 'gasohol/result_set'
require 'gasohol/result'
require 'gasohol/featured'
require 'gasohol/exceptions'

module Gasohol
  
  VERSION = '0.1.0'
  LOGGER = Logger.new(STDOUT)

end