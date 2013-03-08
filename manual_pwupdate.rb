#!/usr/bin/env ruby

require 'cwa_rest'
require './config.rb'
include CwaRest

messages = Array.new

cfg = {
  :verb => :GET,
  :url => CwaConfig.msg_url + "/MessageService/basic/queue/RC-PasswordChange/#{ARGV[0]}",
  :user => CwaConfig.msg_user,
  :password => CwaConfig.msg_pass
}

# Get pending password change requests
response = CwaRest.client cfg
p response
if response['count'].to_i > 0
  messages << { :id => response['messages']['id'], :msg => response['messages']['messageData'] }
end 

# For each request, push the change to the FreeIPA realm
messages.each do |m|
  pw = CwaRest.decrypt(m[:msg]['password'], CwaConfig.msg_aes_key, "AES-128-ECB")
  json = {
    :method => "passwd",
    :params => [ 
      [ m[:msg]['netid'] + "@RC.USF.EDU", pw, "CHANGING_PASSWORD_FOR_ANOTHER_USER" ],
      {}
    ]
  }

  cfg = {
    :verb => :POST,
    :url  => CwaConfig.ipa_url,
    :user => CwaConfig.ipa_user,
    :password => CwaConfig.ipa_pass,
    :json => json
  }

  ipa_resp = CwaRest.client cfg

  if ipa_resp['result'] == nil
    puts Time.now.to_s + " pwupdate.rb :: ERROR => Password change for " + m[:msg]['netid'] + ": " + ipa_resp['error']['message']
  else
    puts Time.now.to_s + " pwupdate.rb :: SUCCESS => Password sync for " + m[:msg]['netid']
    delete_resp = CwaRest.client ({
      :verb => :DELETE,
      :url => CwaConfig.msg_url + "/MessageService/basic/queue/RC-PasswordChange/#{m[:id]}",
      :user => CwaConfig.msg_user,
      :password => CwaConfig.msg_pass
    })
  end

  # Force password expiry update
  pwexp = `/root/cwa_tools/pwexpupdate.sh #{m[:msg]['netid']}`
  if $?.success?
    puts Time.now.to_s + " pwupdate.rb :: User password expiry updated. " + pwexp.chomp
  else
    puts Time.now.to_s + " pwupdate.rb :: Failed to update user password expiry! " + pwexp.chomp
  end
  
end
