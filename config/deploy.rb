set :rvm_ruby_string, ENV['GEM_HOME'].gsub(/.*\//,"")
require "rvm/capistrano"
require 'capistrano_colors'
require 'bundler/capistrano'
require 'airbrake/capistrano'
require "thinking_sphinx/deploy/capistrano"
require "auto_html/capistrano"
set :whenever_command, "bundle exec whenever"
require "whenever/capistrano"

ssh_options[:forward_agent] = true
set :application, "social-innovation"
set :domain, "www.idea-synergy.com"
set :scm, "git"
set :repository, "git://github.com/rbjarnason/social_innovation.git"
set :use_sudo, false
set :deploy_to, "/home/robert/sites/#{application}"
set :user, "robert"
set :deploy_via, :remote_cache
set :shared_children, shared_children + %w[config db/sphinx assets]

role :app, domain
role :web, domain
role :db,  domain, :primary => true

namespace :deploy do
  task :start do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

before 'deploy:update_code' do
 # thinking_sphinx.stop
end

after 'deploy:update_code' do
  thinking_sphinx.configure
  thinking_sphinx.rebuild
end

after 'deploy:finalize_update' do
  run "ln -nfs #{deploy_to}/#{shared_dir}/config/* #{current_release}/config/"
  run "ln -nfs #{deploy_to}/#{shared_dir}/system #{current_release}/public/system"
end

namespace :delayed_job do
  desc "Restart the delayed_job process"
  task :restart, :roles => :app do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec ruby script/delayed_job restart"
  end
end

after "deploy", "delayed_job:restart"

namespace :assets do
  task :precompile, :roles => :web, :except => { :no_release => true } do
    if capture("cd #{latest_release} && #{source.local.log(source.next_revision(current_revision))} vendor/assets/ app/assets/ lib/assets/ | wc -l").to_i > 0
      run "cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assets:precompile"
    else
      logger.info "No changes on assets. Skipping pre-compilation."
    end
  end

  task :cleanup, :roles => :web do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake assets:clean"
  end
end

#after :deploy, "assets:precompile"
