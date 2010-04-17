require 'mongo'
require 'mongoid'

File.open(File.join(RAILS_ROOT, 'config/mongoid.yml'), 'r') do |f|
  @settings = YAML.load(f)[RAILS_ENV]
end

connection = Mongo::Connection.new(@settings["host"])
Mongoid.database = connection.db(@settings["database"])
if @settings["username"]
  Mongoid.database.authenticate(@settings["username"], @settings["password"])
end


# Mongoid.configure do |config|
#  name = @settings["database"]
#  host = @settings["host"]
#  config.master = Mongo::Connection.new.db(name)
#  config.slaves = [
#    Mongo::Connection.new(host, @settings["slave_one"]["port"], :slave_ok => true).db(name),
#    Mongo::Connection.new(host, @settings["slave_two"]["port"], :slave_ok => true).db(name)
#  ]
# end
