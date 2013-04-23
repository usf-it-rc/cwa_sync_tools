#!/usr/bin/env ruby
#
# RubyCron script to check for current CPU time on CIRCE
# May need to use two db calls in order to build hash
# on SGE data to avoid possible timeouts in the future.
#
# Comments kept for debugging purposes.
#
# John DeSantis desantis@mail.usf.edu
#
# Added Hash, extra DB call - John DeSantis 04/22/2013

require 'pg'
require 'rcqacct'
require 'sgelistfix'
require './config.rb'

sge_list = Array.new
sge_list = SGElist.new("defaultAllocations").listclean.split(/\s+/)  # We'll supply a listname for now
sge_list.delete_if { |x| x == "DEPT" }
sge_list.drop(9)

dbstr = "dbname=redmine user=#{CwaConfig.redmine_db_user} password=#{CwaConfig.redmine_db_pass} host=#{CwaConfig.redmine_db_host}"

userdets = Hash.new
userids = String.new

# Populate Hashes with initial data 
dbconn = PG::Connection.open(dbstr)
t_query = dbconn.exec("select user_id,used_hours,time_in_hours,approved,last_reported_hours from cwa_allocations where user_id > 10000")
t_query.values.each do |i|
  user = Rcqacct.new(i[0].chomp)
  userids += "'#{user.uname}',"
  used_hours,time_in_hours,approved,last_reported_hours = i[1].to_i,i[2].to_i,i[3],i[4].to_i
  userdets.store(user.uname,{"uid"=>"#{i[0].chomp}","used_hours"=>"#{i[1].chomp}","time_in_hours"=>"#{i[2].chomp}","approved"=>"#{i[3].chomp}","last_reported_hours"=>"#{i[4].chomp}","arco_hours"=>"0"}) 
end
dbarco = PG::Connection.open("dbname=arco user=#{CwaConfig.arco_db_user} password=#{CwaConfig.arco_db_pass} host=#{CwaConfig.arco_db_host}")
t_query = dbarco.exec("select cpu_time,owner from view_user_cputime where owner in (#{userids.chop})")
t_query.values.each do |i|
  userdets[i[1]]["arco_hours"] = ((i[0].chomp.to_i / 60) / 60)
end
dbarco.close

# Process statistics
rows = 0
userdets.each_key do |uid|
  if userdets[uid]["used_hours"].to_i < userdets[uid]["time_in_hours"].to_i && userdets[uid]["approved"] == "t"
    unless sge_list.include?(uid)
      puts "Adding #{uid} to defaultAllocations userset list."
      Rcqacct.new(uid).listadd = "defaultAllocations"
    end
  end
  if userdets[uid]["used_hours"].to_i == 0 && userdets[uid]["last_reported_hours"].to_i == 0
    #puts "test2 match: #{uid}"
    u_query = dbconn.exec("update cwa_allocations set (used_hours,last_reported_hours) = ('#{userdets[uid]["arco_hours"]}','#{userdets[uid]["arco_hours"]}') where user_id = '#{userdets[uid]["uid"]}'")
    rows += u_query.cmd_tuples
  elsif userdets[uid]["used_hours"].to_i == 0 && userdets[uid]["last_reported_hours"].to_i > 0
    #puts "test3: #{uid}, used hours must be set to hours reported by qacct/arco minus last_reported_hours"
    t_var = (userdets[uid]["arco_hours"].to_i - userdets[uid]["last_reported_hours"].to_i)
    u_query = dbconn.exec("update cwa_allocations set used_hours = '#{t_var}' where user_id = '#{userdets[uid]["uid"]}'")
    rows += u_query.cmdtuples
  end
  if userdets[uid]["used_hours"].to_i > 0 && userdets[uid]["last_reported_hours"].to_i == 0
    # must update used_hours table to used_hours + arco
    t_var = (userdets[uid]["used_hours"].to_i + userdets[uid]["arco_hours"])
    u_query = dbconn.exec("update cwa_allocations set used_hours = '#{t_var}' where user_id = '#{userdets[uid]["uid"]}'")
    u_query = dbconn.exec("update cwa_allocations set last_reported_hours = '#{userdets[uid]["arco_hours"]}' where user_id = '#{userdets[uid]["uid"]}'")
    rows += u_query.cmdtuples
  elsif userdets[uid]["used_hours"].to_i >= 0 && userdets[uid]["last_reported_hours"].to_i >= 0 
    #puts "test 4 match: #{user_id.uname} - set used_hours to ((sge - last_reported_hours) + used_hours)"
    unless userdets[uid]["last_reported_hours"].to_i == userdets[uid]["arco_hours"].to_i
      #puts "#{uid} has used additional cputime this run. last hours reported: #{userdets[uid]["last_reported_hours"]} cputime: #{userdets[uid]["arco_hours"]}"
      t_var = ( (userdets[uid]["arco_hours"].to_i - userdets[uid]["last_reported_hours"].to_i) + userdets[uid]["used_hours"].to_i)
      u_query = dbconn.exec("update cwa_allocations set used_hours = '#{t_var}' where user_id = '#{userdets[uid]["uid"]}'")
      u_query = dbconn.exec("update cwa_allocations set last_reported_hours = '#{userdets[uid]["arco_hours"]}' where user_id = '#{userdets[uid]["uid"]}'")
      rows += u_query.cmdtuples
    end
  end
  if userdets[uid]["used_hours"].to_i >= userdets[uid]["time_in_hours"].to_i && userdets[uid]["approved"] == "t"
    if sge_list.include?(uid)
      puts "Removing #{uid} from defaultAllocations userset list and setting allocation_finished to current timestamp."
      Rcqacct.new(uid).listdel = "defaultAllocations"
      u_query = dbconn.exec("update cwa_allocations set allocation_finished = current_timestamp where user_id = '#{userdets[uid]["uid"]}'")
      rows += u_query.cmdtuples
    end
  end
end
dbconn.close
puts "Total rows: #{rows}"
