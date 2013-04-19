#!/usr/bin/env ruby

# CWA dashboard plugin script
# Populates specific SGE details into
# cwa_user_metrics table.
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
  userq = dbredm.exec("select exists (select user_id from cwa_user_metrics where user_id = '#{user[:uidnumber]}')")

  # we use a view defined in arco to make this fast and accurate
  avgq  = dbarco.exec("select count,total_wallclock,average_wallclock,average_cputime,total_cputime from view_user_30day where owner='#{user[:login]}' LIMIT 1")  

  # Insert nothing for users with nothing
  if avgq.count == 0
    totjobs = 0
    totwall = 0
    avgwall = 0.0
    avgcpu  = 0.0
    totcpu  = 0
  else
    values = avgq.values[0]
    totjobs = "%d" % values[0]
    totwall = "%d" % values[1].to_i
    avgwall = "%0.2f" % values[2].to_f
    avgcpu  = "%0.2f" % values[3].to_f
    totcpu  = "%d" % values[4].to_i
  end

  #p [ user[:login], totjobs, totwall, avgwall, totcpu, avgcpu ]

  uq = nil

  # If they have an entry in the metrics table, update it.  Otherwise, insert
  case userq.values[0][0]
    when "t"
      uq = dbredm.exec("update cwa_user_metrics set (total_cputime,average_cputime,total_walltime,average_walltime,total_jobs) = ('#{totcpu}','#{avgcpu}','#{totwall}','#{avgwall}','#{totjobs}') where user_id = '#{user[:uidnumber]}'")
    when "f"
      uq = dbredm.exec("insert into cwa_user_metrics (user_id,total_cputime,average_cputime,total_walltime,average_walltime,total_jobs) values ('#{user[:uidnumber]}','#{totcpu}','#{avgcpu}','#{totwall}','#{avgwall}','#{totjobs}')")
  end
end
dbredm.close
dbarco.close
