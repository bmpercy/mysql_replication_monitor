require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "mysql_replication_monitor"
    gemspec.summary = "a helper class for monitoring replication between two mysql dbs. Rails environment only and depends on multiple_connection_handler."
    gemspec.description = <<DESC
Connects to both master and slave and compares their status, allowing you to check whether
the slave is running and whether slave is caught up to master
DESC
    gemspec.email = "percivalatumamibuddotcom"
    gemspec.homepage = "http://github.com/bmpercy/mysql_replication_monitor"
    gemspec.authors = ['Brian Percival']
    gemspec.files = ["mysql_replication_monitor.gemspec",
                     "[A-Z]*.*",
                     "lib/**/*.rb"]
    gemspec.add_dependency 'multiple_connection_handler'
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
