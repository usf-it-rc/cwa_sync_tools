#!/usr/bin/env ruby

require 'cwa_rest'
require './config.rb'
include CwaRest

# Gives us a list of pending account host attrib adds
response = CwaRest.client({
  :verb => :DELETE,
  :url => CwaConfig.msg_url + "/MessageService/basic/queue/RC-PasswordChange/#{ARGV[0]}",
  :user => CwaConfig.msg_user,
  :password => CwaConfig.msg_pass
})

p response

#response['messages'].each do |m|
#  p m['messageData']
#  #puts m['messageData']['username'] + " => " + m['messageData']['host']
#end
