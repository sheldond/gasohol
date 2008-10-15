require 'rubygems'
require 'active_record'

ActiveRecord::Base.establish_connection({ :adapter => 'mysql', :database => 'gasohol_development', :user => 'root', :password => '', :host => 'localhost' })
conn = ActiveRecord::Base.connection

# conn.execute("insert into zips values('AMF O''Hare','IL',60666,773,17031,'Cook','P','CST','Y',41.9741,87.9128,0,1600,6,602,'P',1,-1);")

File.open('inserts.txt','r').each_line do |line|
  conn.execute(line)
end