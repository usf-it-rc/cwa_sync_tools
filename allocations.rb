#!/usr/bin/env ruby
#
# RubyCron script to check for current CPU time on CIRCE
# May need to use two db calls in order to build hash
# on SGE data to avoid possible timeouts in the future.
#
# Comments kept for debugging purposes.
#
# John DeSantis desantis@mail.usf.edu 

require 'pg'
require 'rcqacct'
require 'sgelistfix'
require './config.rb'

sge_list = Array.new
sge_list = SGElist.new("defaultAllocations").listclean.split(/\s+/)  # We'll supply a listname for now
sge_list = sge_list.length <= 10 ? sge_list = sge_list.drop(9) : sge_list = sge_list.drop(10)

dbstr = "dbname=redmine user=#{CwaConfig.redmine_db_user} password=#{CwaConfig.redmine_db_pass} host=#{CwaConfig.redmine_db_host}"

dbconn = PG::Connection.open(dbstr)
rows = 0
t_query = dbconn.query('select user_id,used_hours,time_in_hours,approved,last_reported_hours,allocation_finished from cwa_allocations')
t_query.values.each do |i|
  unless i[0].to_i <= 500
    user_id,used_hours,time_in_hours,approved,last_reported_hours,allocation_finished = Rcqacct.new(i[0].to_i),i[1].to_i,i[2].to_i,i[3],i[4].to_i,i[5]
    if used_hours < time_in_hours && approved == "t"
      unless sge_list.include?(user_id.uname)
        ## puts "test 1 match: #{user_id.uname}. Adding to defaultAllocations"
        user_id.listadd = "defaultAllocations" 
      end
    end
    if used_hours == 0 && last_reported_hours == 0
      ## puts "test2 match: #{user_id.uname}"
      u_query = dbconn.exec("update cwa_allocations set (used_hours,last_reported_hours) = ('#{user_id.cputime}','#{user_id.cputime}') where user_id = '#{i[0]}'")
      rows += u_query.cmd_tuples
    elsif used_hours == 0 && last_reported_hours > 0
      ## puts "test3: #{user_id.uname}, used hours must be set to hours reported by qacct/arco minus last_reported_hours"
      ## puts t_var = (user_id.cputime - last_reported_hours)
      u_query = dbconn.exec("update cwa_allocations set used_hours = '#{t_var}' where user_id = '#{i[0]}'")
      rows += u_query.cmdtuples
    elsif used_hours > 0 && last_reported_hours > 0 
      ## puts "test 4 match: #{user_id.uname} - set used_hours to ((sge - last_reported_hours) + used_hours)"
      unless last_reported_hours == user_id.cputime
        ## puts "#{user_id.uname} has not used cputime this run. last hours reported: #{last_reported_hours} cputime: #{user_id.cputime}"
        t_var = ( (user_id.cputime - last_reported_hours) + used_hours)
        u_query = dbconn.exec("update cwa_allocations set used_hours = '#{t_var}' where user_id = '#{i[0]}'")
        u_query = dbconn.exec("update cwa_allocations set last_reported_hours = '#{user_id.cputime}' where user_id = '#{i[0]}'")
        rows += u_query.cmdtuples
      end
    end
    if used_hours >= time_in_hours && approved == "t"
      if sge_list.include?(user_id.uname)
        ## puts "test5 match: remove #{user_id.uname} from defaultAllocations user list and allocation_finished must be set to current timestamp"
        user_id.listdel = "defaultAllocations"
        u_query = dbconn.exec("update cwa_allocations set allocation_finished = current_timestamp where user_id = '#{i[0]}'")
        rows += u_query.cmdtuples
      end
    end
  end
end
puts "total rows affected: #{rows}" unless rows == 0
dbconn.close
