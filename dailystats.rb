#!/usr/bin/env ruby

# Daily statistics from view_user_today
# Populates specific SGE details into
# cwa_stats table.
#
# John DeSantis desantis@mail.usf.edu
#
# 04/15/2013 - Brian Smith - Did a large refactor

require './config.rb'
require 'pg'

# Processing Array
cwa_users = Array.new

rows = 0

# Need two DBs
dbredm = PG::Connection.open("dbname=redmine user=#{CwaConfig.redmine_db_user} password=#{CwaConfig.redmine_db_pass} host=#{CwaConfig.redmine_db_host}")
dbarco = PG::Connection.open("dbname=arco user=#{CwaConfig.arco_db_user} password=#{CwaConfig.arco_db_pass} host=#{CwaConfig.arco_db_host}")

# Get our list of user ids and logins from the users table
dbredm.exec("select id,login from users where id > 10000").values.each do |i|
  cwa_users.push({ :login => i[1].chomp, :uidnumber => i[0].chomp })
end

# For each user, lets extract usage data and put it into the cwa_user_metrics table
cwa_users.each do |user|
  # we use a view defined in arco to make this fast and accurate
  avgq  = dbarco.exec("select count,total_wallclock,total_cputime from view_user_today where owner='#{user[:login]}' LIMIT 1")  

  # Insert nothing for users with nothing
  if avgq.count != 0
    values = avgq.values[0]
    totjobs = "%d" % values[0]
    totwall = "%d" % values[1].to_i
    totcpu  = "%d" % values[2].to_i
    dbredm.exec("insert into cwa_stats (user_id,cputime,wallclock,job_count,date,created_at,updated_at) values ('#{user[:uidnumber]}','#{totcpu}','#{totwall}','#{totjobs}', NOW(), NOW(), NOW())")
  end
end
dbredm.close
dbarco.close
