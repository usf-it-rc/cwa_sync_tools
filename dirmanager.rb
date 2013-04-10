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
      :version => '2.46',
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
    FileUtils.mkdir_p(home_dir, :mode => 0700)
    FileUtils.cp_r("/etc/skel/.", home_dir)
    FileUtils.chown_R(uid, uid, home_dir)
    FileUtils.chmod_R("o-rwx", home_dir)
  end

  # work directory
  if !File.directory?(work_dir) && work_dir =~ /^\/work\/[a-z]{1}\/.*$/
    FileUtils.mkdir_p(work_dir, :mode => 0700)
    FileUtils.chown(uid, uid, work_dir)
  end
end

# Get list of all groups
response = CwaRest.client({
  :verb => :POST,
  :url => CwaConfig.ipa_url,
  :user => CwaConfig.ipa_user,
  :password => CwaConfig.ipa_pass,
  :json => {
    :method => "group_find",
    :params => [ [], {
      :raw => false,
      :all => false,
      :timelimit => 0,
      :sizelimit => 0,
      :version => '2.46',
      :pkey_only => false
    } ]
  }
})

response['result']['result'].each do |r|
  next if r['cn'].first == "ipausers"

  dir = "/shares/" + r['cn'].first
  next if r['gidnumber'] == nil

  gid = r['gidnumber'].first 

  begin
    owner = eval(r['description'].first)[:owner]
  rescue
    next
  end

  if !File.directory?(dir)
    FileUtils.mkdir_p(dir)
    FileUtils.chmod("u=rwx,g=rwx,o-rwx", dir)
    FileUtils.chmod("g+s", dir)
    FileUtils.chown(owner, gid, dir)
  end
end
