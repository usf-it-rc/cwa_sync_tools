#!/usr/bin/env ruby

# Disk notification cron script.
# Checks for disk usage >= 1TB,
# and notifies users via email.
#
# John DeSantis desantis@mail.usf.edu

require 'pg'
require 'rcqacct'
require 'mail'
require './config.rb'

# Use a hereto document versus a file to read.
message = <<note
Our scripts detected that your /work share is over 1 TB.  Please note that Research Computing does not archive or back-up any data residing on /work.
If you have important data on your share, you should archive it to your local workstation or on /home.  

If you have any questions or concerns, please contact Research Computing.
note


dbstr = "dbname=redmine user=#{CwaConfig.redmine_db_user} password=#{CwaConfig.redmine_db_pass} host=#{CwaConfig.redmine_db_host}"
# Grab userid list from cwa_user_metrics table.
dbconn = PG::Connection.open(dbstr)
userq = dbconn.exec("select users.id,cwa_user_metrics.disk_usage_work,users.mail from users,cwa_user_metrics where users.id = cwa_user_metrics.user_id and disk_usage_work != 0;")
userq.values.each do |i|
  userid = Rcqacct.new(i[0])
  disk_usage = i[1].chomp.to_i
  mail = i[2].chomp
  # Let's check for >= 1TB disk usage on /work
  unless disk_usage.to_s =~ /^.{0,3}$/ || disk_usage.to_i == 0
    mail = Mail.deliver do
      from 'do-not-reply@rc.usf.edu'
      to "#{mail}" 
      subject 'USF Research Computing: Disk usage statistics on /work'
      # Message needs to include reported disk usage
      body "Hello #{userid.uname},\n\n#{message}\nReported disk usage: #{disk_usage} GB" 
    end
  end
end
dbconn.close
