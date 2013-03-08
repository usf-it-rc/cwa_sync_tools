#!/usr/bin/env ruby

require 'cwa_rest'
require './config.rb'
include CwaRest

if ARGV[0] == nil
  puts "This program requires one argument: a USF NetID"
  exit 1
end

cfg = {
  :verb => :GET,
  :url => CwaConfig.msg_url + "/MessageService/basic/queue/RC-AccountChange",
  :user => CwaConfig.msg_user,
  :password => CwaConfig.msg_pass
}

response = CwaRest.client cfg

# No need to pop in an extra request
if response['messages'] != nil
  response['messages'].each do |m|
    if m['messageData']['username'] == ARGV[0].to_s
      puts "Add request for user " + ARGV[0] + " already exists!"
      exit 0
    end
  end
end

cfg[:verb] = :POST
cfg[:json] = {
  "apiVersion" => "1",
  "createProg" => "EDU:USF:RC:update_tool.rb",
  "messageData" => {
     "host"     => "rc.usf.edu",
     "username" => ARGV[0],
     "accountStatus" => "active",
     "accountType" => "Unix"
  }     
}

response = CwaRest.client cfg

p response
if response['messages']['status'] == "pending"
  puts "Add request pushed successfully for user " + ARGV[0]
else
  puts "Add request failed for user " + ARGV[0]
  exit 1
end

exit 0
