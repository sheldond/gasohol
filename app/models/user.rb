class User < ActiveRecord::Base
  
  validates_presence_of :name, :login, :password, :email
  validates_uniqueness_of :login, :email
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_confirmation_of :password, :on => :create
  
end
