#!/usr/bin/env ruby

require 'cwa_rest'
require './config.rb'
include CwaRest

# Gives us a list of pending account host attrib adds
response = CwaRest.client({
  :verb => :GET,
  :url => CwaConfig.msg_url + "/MessageService/basic/queue/RC-AccountChange",
  :user => CwaConfig.msg_user,
  :password => CwaConfig.msg_pass
})

p response

response['messages'].each do |m|
  puts m['messageData']['username'] + " => " + m['messageData']['host']
end
