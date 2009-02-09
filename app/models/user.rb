class User < ActiveRecord::Base
  
  belongs_to :invite
  has_many :queries, :order => 'created_at desc'
  has_many :polls
  
  validates_presence_of :name, :login, :password, :email
  validates_uniqueness_of :login, :email
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_confirmation_of :password, :on => :create
  
end
