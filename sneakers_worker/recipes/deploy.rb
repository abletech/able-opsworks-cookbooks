include_recipe 'sneakers_worker::template'
# Adapted from deploy::rails: https://github.com/aws/opsworks-cookbooks/blob/master/deploy/recipes/rails.rb
include_recipe 'deploy'

node[:deploy].each do |application, deploy|

  if deploy[:application_type] != 'worker'
    Chef::Log.debug("Skipping sneakers_worker::deploy application #{application} as it is not a worker app")
    next
  end
  Chef::Log.debug("sneakers_worker::deploy application #{application} as it is a  worker app")

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  # This stops all delayed jobs which have a pid file
  bash "sneakers_worker-#{application}-stop" do
    cwd "#{deploy[:deploy_to]}/current"
    user 'deploy'
    code "RAILS_ENV=#{deploy[:rails_env]} bin/sneakers_worker stop"

    action :nothing
  end

  bash "sneakers_worker-#{application}-reload" do
    user 'root'

    # We unmonitor the delayed jobs because we will stop them manually
    # They will become monitored again when restarted
    # Sleeps after each command because monit does not wait for the server
    code <<CODE
monit -g sneakers_worker unmonitor
sleep 1
monit reload
sleep 1
CODE

    action :nothing
    subscribes :run, "template[/etc/monit.d/#{application}_sneakers_worker.monitrc]", :immediately
    notifies :run, "bash[sneakers_worker-#{application}-stop]", :immediately
  end
end

include_recipe 'sneakers_worker::restart'
