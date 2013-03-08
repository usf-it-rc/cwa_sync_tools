#!/usr/bin/env ruby

require 'cwa_rest'
require './config.rb'
require 'fileutils'
include CwaRest

# Get list of all users
response = CwaRest.client({
  :verb => :POST,
  :url => CwaConfig.ipa_url,
  :user => CwaConfig.ipa_user,
  :password => CwaConfig.ipa_pass,
  :json => {
    :method => "user_find",
    :params => [ [], {
      :raw => false,
      :all => false,
      :timelimit => 0,
      :sizelimit => 0,
      :version => '2.34',
      :whoami => false,
      :pkey_only => false
    } ]
  }
})

# Check for fun errors
if response.has_key?('error')
  if response[:error] != nil
    puts response['error']
    exit 1
  end
end

# for each returned result
response['result']['result'].each do |r|
  home_dir = r['homedirectory'].first
  work_dir = r['homedirectory'].first.gsub(/\/home\//,"\/work\/")
  uid = r['uidnumber'].first

  # home directory
  if !File.directory?(home_dir) && home_dir =~ /^\/home\/[a-z]{1}\/.*$/
    Dir.mkdir(home_dir, 0700)
    FileUtils.cp_r("/etc/skel/", home_dir)
    FileUtils.chown_R(uid, uid, home_dir)
    FileUtils.chmod_R("o-rwx", home_dir)
  end

  # work directory
  if !File.directory?(work_dir) && work_dir =~ /^\/work\/[a-z]{1}\/.*$/
    Dir.mkdir(work_dir, 0700)
    File.chown(uid, uid, work_dir)
  end
end
