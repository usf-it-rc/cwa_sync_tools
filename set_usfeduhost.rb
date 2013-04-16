#!/usr/bin/env ruby

require 'cwa_rest'
require './config.rb'
require 'rubygems'
require 'net/ldap'
include CwaRest



cfg = {
  :verb => :POST,
  :url => CwaConfig.ipa_url,
  :user => CwaConfig.ipa_user,
  :password => CwaConfig.ipa_pass,
  :json => {
    :method => 'user_find',
    :params => [ [], {} ]
  }
}

response = CwaRest.client cfg

response['result']['result'].each do |entry|
  netid = entry["uid"].first

  next if [ "admin", "rc-user-svcacct", "rc-host-svcacct" ].include?(netid)

  ldap = Net::LDAP.new :host => "cims-ds1.it.usf.edu",
    :port => 636,
    :encryption => :simple_tls

  treebase = "ou=usf,o=usf.edu"
  filter = Net::LDAP::Filter.join(Net::LDAP::Filter.eq("uid", netid), Net::LDAP::Filter.eq("USFeduHost", "rc.usf.edu"))
  
  results = ldap.search(:base => treebase, :filter => filter) 

  next if results.first != nil
  cfg = {
    :url => CwaConfig.msg_url + "/MessageService/basic/queue/RC-AccountChange",
    :user => CwaConfig.msg_user,
    :password => CwaConfig.msg_pass,
    :verb => :POST,
    :json => {
      "apiVersion" => "1",
      "createProg" => "EDU:USF:RC:add_usfeduhost.rb",
      "messageData" => {
        "host" => "rc.usf.edu",
        "username" => netid,
        "accountStatus" => "active",
        "accountType" => "Unix"
      }
    }     
  }

  response = CwaRest.client cfg

  if response['messages']['status'] == "pending"
    puts "Add request pushed successfully for user " + netid
  else
    puts "Add request failed for user " + netid
    exit 1
  end
end

exit 0
