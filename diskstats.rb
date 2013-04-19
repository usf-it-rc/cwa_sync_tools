#!/usr/bin/env ruby

require './config.rb'
require 'pg'

pg_conn = "dbname=redmine user=#{CwaConfig.redmine_db_user} password=#{CwaConfig.redmine_db_pass} host=#{CwaConfig.redmine_db_host}"

# Rudimentary run in progress check
if File.exists?("/var/run/disk_tally.tmp")
  puts "run in progress..."
  exit
end

# Processing Structures
stats = Hash.new
xfs_quota = Array.new

# Since getting work file system stats can take
# a UID as an argument, we want all UID's first
# from the DB
system("touch /var/run/disk_tally.tmp")
dbconn = PG::Connection.open(pg_conn)
u_query = dbconn.exec("select id from users where id > 10000")
u_query.values.each do |i|
  stats.store(i[0],{})
end
dbconn.close

# Start with /work since it's faster
# and populate our base hash
stats.each_key do |user|
  i = IO.popen("lfs quota -u #{user} /work | awk '/^Disk/ { printf \"%s:\", $5 } \/\\/work\/ { print $2 }'","r")
  uid,size = i.readlines.to_s.gsub(/\[|"|\\n|\]/,'').split(":")[0..1]
  if size == "4"
    stats.store(uid,{"work"=>"0","home"=>""})
  else
    size = size.to_f
    stats.store(uid,{"work"=>((size/1024)/1024),"home"=>""})
  end
end

# Move on to /home
i = IO.popen("/usr/sbin/xfs_quota -x -c \"quot -un -b\" /export/home","r")
  xfs_quota += i.readlines
i.close

# Process xfs_stats
xfs_quota.each do |line|
  size,user = line.chomp.gsub(/\s+/,'').split("#")[0..1]
  if stats.has_key?(user)
    size = size.to_f
    stats[user]["home"] = ((size/1024)/1024)
  end
end

## Re-establish DB connection to populate fields
rows = 0
dbconn = PG::Connection.open(pg_conn)
stats.each_key do |uid|
  unless stats[uid]["home"].to_s == ""
    u_query = dbconn.exec("update cwa_user_metrics set (disk_usage_home,disk_usage_work) = ('#{stats[uid]["home"]}','#{stats[uid]["work"]}') where user_id = '#{uid}'")
    rows += u_query.cmdtuples()
  else
    u_query = dbconn.exec("update cwa_user_metrics set (disk_usage_home,disk_usage_work) = ('0.00','#{stats[uid]["work"]}') where user_id = '#{uid}'")
    rows += u_query.cmdtuples()
  end
end

puts "Total rows: #{rows}"
system("rm /var/run/disk_tally.tmp")
