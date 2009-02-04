# This is a sample Capistrano config file for EC2 on Rails.
# It should be edited and customized.
 
set :application, "gasohol"
 
# default_run_options[:pty] = true
set :repository, "git://github.com/cannikin/gasohol.git"
set :scm, "git"
set :scm_passphrase, "" #This is your custom users password
set :branch, "master"
set :deploy_to, "/mnt/app"
 
set :user, 'root'
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa")]
 
role :app, "ec2-174-129-175-160.compute-1.amazonaws.com", "ec2-174-129-147-77.compute-1.amazonaws.com"
role :web, "ec2-174-129-175-160.compute-1.amazonaws.com", "ec2-174-129-147-77.compute-1.amazonaws.com"
role :db, "ec2-174-129-175-160.compute-1.amazonaws.com", :primary => true
 
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
 
namespace :deploy do
  desc "Restart Application"
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end
end
 
before 'deploy', 'deploy:web:disable'
before 'deploy:migrations', 'deploy:web:disable'
after 'deploy', 'deploy:web:enable'
after 'deploy:migrations', 'deploy:web:enable'
after 'deploy:symlink', 'ec2:set_permissions'