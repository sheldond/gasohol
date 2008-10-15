require 'rubygems'
require 'cgi'
require 'google'

print 'Search for: '
search = gets.chomp
results = Google.new(search, :num => 15, :start => 1, :search_url => 'http://gsa7.enterprisedemo-google.com/search')

puts results.total_results.to_s + ' results'