# This is a sample Capistrano config file for EC2 on Rails.
# It should be edited and customized.

set :application, "gasohol"

# default_run_options[:pty] = true
set :repository,  "git://github.com/cannikin/gasohol.git"
set :scm, "git"
set :scm_passphrase, "" #This is your custom users password
set :branch, "master"
set :deploy_to, "/mnt/app"

set :user, 'root'
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa")] 


# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
# set :deploy_to, "/var/www/#{application}"

# If you aren't using Subversion to manage your source code, specify
# your SCM below:
# set :scm, :subversion

role :app, "ec2-174-129-175-160.compute-1.amazonaws.com"
role :web, "ec2-174-129-175-160.compute-1.amazonaws.com"
role :db,  "ec2-174-129-175-160.compute-1.amazonaws.com", :primary => true


=begin
# NOTE: for some reason Capistrano requires you to have both the public and
# the private key in the same folder, the public key should have the 
# extension ".pub".
ssh_options[:keys] = ["#{ENV['HOME']}/.ssh/searchpoc-keypair"]

# Your EC2 instances. Use the ec2-xxx....amazonaws.com hostname, not
# any other name (in case you have your own DNS alias) or it won't
# be able to resolve to the internal IP address.
role :web,      "75.101.162.64"
role :app,      "75.101.162.64"
role :memcache, "75.101.162.64"
role :db,       "75.101.162.64", :primary => true
# role :db,       "ec2-56-xx-xx-xx.z-1.compute-1.amazonaws.com", :primary => true, :ebs_vol_id => 'vol-12345abc'
# optinally, you can specify Amazon's EBS volume ID if the database is persisted 
# via Amazon's EBS.  See the main README for more information.

# Whatever you set here will be taken set as the default RAILS_ENV value
# on the server. Your app and your hourly/daily/weekly/monthly scripts
# will run with RAILS_ENV set to this value.
set :rails_env, "production"

# EC2 on Rails config. 
# NOTE: Some of these should be omitted if not needed.
set :ec2onrails_config, {
  # S3 bucket and "subdir" used by the ec2onrails:db:restore task
  # NOTE: this only applies if you are not using EBS
  :restore_from_bucket => "gasohol_restore",
  :restore_from_bucket_subdir => "database",
  
  # S3 bucket and "subdir" used by the ec2onrails:db:archive task
  # This does not affect the automatic backup of your MySQL db to S3, it's
  # just for manually archiving a db snapshot to a different bucket if 
  # desired.
  # NOTE: this only applies if you are not using EBS
  :archive_to_bucket => "gasohol_archive",
  :archive_to_bucket_subdir => "db-archive/#{Time.new.strftime('%Y-%m-%d--%H-%M-%S')}",
  
  # Set a root password for MySQL. Run "cap ec2onrails:db:set_root_password"
  # to enable this. This is optional, and after doing this the
  # ec2onrails:db:drop task won't work, but be aware that MySQL accepts 
  # connections on the public network interface (you should block the MySQL
  # port with the firewall anyway). 
  # If you don't care about setting the mysql root password then remove this.
  :mysql_root_password => "bosco",
  
  # Any extra Ubuntu packages to install if desired
  # If you don't want to install extra packages then remove this.
  # :packages => ["logwatch", "imagemagick"],
  
  # Any extra RubyGems to install if desired: can be "gemname" or if a 
  # particular version is desired "gemname -v 1.0.1"
  # If you don't want to install extra rubygems then remove this
  # :rubygems => ["hpricot","chronic","mislav-will_paginate"],
  
  # Defines the web proxy that will be used.  Choices are :apache or :nginx
  :web_proxy_server => :apache,
  
  # extra security measures are taken if this is true, BUT it makes initial
  # experimentation and setup a bit tricky.  For example, if you do not
  # have your ssh keys setup correctly, you will be locked out of your
  # server after 3 attempts for upto 3 months.  
  :harden_server => false,
  
  # Set the server timezone. run "cap -e ec2onrails:server:set_timezone" for 
  # details
  :timezone => "US/Pacific",
  
  # Files to deploy to the server (they'll be owned by root). It's intended
  # mainly for customized config files for new packages installed via the 
  # ec2onrails:server:install_packages task. Subdirectories and files inside
  # here will be placed in the same structure relative to the root of the
  # server's filesystem. 
  # If you don't need to deploy customized config files to the server then
  # remove this.
  # :server_config_files_root => "../server_config",
  
  # If config files are deployed, some services might need to be restarted.
  # If you don't need to deploy customized config files to the server then
  # remove this.
  # :services_to_restart => %w(postfix sysklogd),
  
  # Set an email address to forward admin mail messages to. If you don't
  # want to receive mail from the server (e.g. monit alert messages) then
  # remove this.
  # :mail_forward_address => "you@yourdomain.com",
  
  # Set this if you want SSL to be enabled on the web server. The SSL cert 
  # and key files need to exist on the server, The cert file should be in
  # /etc/ssl/certs/default.pem and the key file should be in
  # /etc/ssl/private/default.key (see :server_config_files_root).
  # :enable_ssl => true
}

# disable backup of MySQL to S3
#after "ec2onrails:setup", :disable_slave_db_backup
#after "ec2onrails:server:deploy_files", :disable_slave_db_backup
#task :disable_slave_db_backup, :roles => :db do
#    sudo "rm -rf /etc/cron.d/backup_app_db_to_s3"
#end

=end

# custom maintenance page
namespace :deploy do
  namespace :web do
    desc 'Serve up a custom maintenance page'
    task :disable, :roles => :web do
      require 'erb'
      on_rollback { run "rm #{shared_path}/system/maintenance.html" }

      reason = ENV['REASON']
      deadline = ENV['UNTIL']
      
      template = File.read("app/views/layouts/maintenance.html.erb")
      page = ERB.new(template).result(binding)
      
      put page, "#{shared_path}/system/maintenance.html", :mode => 0644
    end
  end
end

namespace :ec2 do
  desc "Change permissions on /mnt/app directory to be owned by app"
  task :set_permissions do
    run "chown -R app:app /mnt/app"
  end
end

namespace :passenger do
  desc "Restart Application"
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end
end

before 'deploy', 'deploy:web:disable'
before 'deploy:migrations', 'deploy:web:disable'
after 'deploy', 'deploy:web:enable'
after 'deploy:migrations', 'deploy:web:enable'

after 'deploy:update', 'ec2:set_permissions'

after 'deploy', "passenger:restart"