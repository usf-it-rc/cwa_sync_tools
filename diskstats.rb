#!/usr/bin/env ruby
# 
# Cron script to update disk usage statistics
# per CWA user.
#
# John DeSantis desantis@mail.usf.edu 04/29/2013

require 'pg'
require './config.rb'

# Database details
dbstr = "dbname=redmine user=#{CwaConfig.redmine_db_user} password=#{CwaConfig.redmine_db_pass} host=#{CwaConfig.redmine_db_host}" 

# File systems to check. Separate with pipe.
fs = "work|home"
ftype = Regexp.new(fs)

# Processing Structures
old_out = $stdout
stats = Hash.new
file_systems = Array.new
proctemp = Array.new
coltemp = Array.new
tnum = 0
rows = 0

# Get file system details
# and process data
tmp = IO.popen("cat /etc/mtab","r")
proctemp += tmp.readlines
tmp.close
proctemp.select do |i|
  if i =~ ftype
    # sunrpc /var/lib/nfs/rpc_pipefs rpc_pipefs rw 0 0
    i.match(/^\S+\s(\S+)\s(\S+)/)
    file_systems.push "#{$1} #{$2}" 
  end
end
proctemp.clear

# Build our Hash using the UID as the primary key
# and then iterate over specified file systems as sub keys.
dbconn = PG::Connection.open(dbstr)
fs.split("|").each do |fst|
  c_query = dbconn.exec("select column_name from information_schema.columns where table_name = 'cwa_user_metrics' and column_name like '%#{fst}%'")
  c_query.values.each do |dbc|
    coltemp[tnum] = Array.new
    coltemp[tnum].push fst, dbc[0]
  end
  tnum += 1
end
u_query = dbconn.exec("select id from users where id > 10000")
u_query.values.each do |i|
  uid = i[0].chomp
  unless stats.has_key?(uid)
    stats[uid] = Hash.new
  end
  file_systems.each do |j|
    unless stats[uid].has_key?(j.split(/ /)[0])
      stats[uid][j.split(/ /)[0]] = 0
    end
  end
end
dbconn.close

# XFS in use?  If so, a temporary file should be created
# for parsing in data due to processing time(s)
file_systems.each do |x|
  if x.split(/ /)[1] =~ /xfs/
    tmp = File.open("/tmp/xfs_details.txt","w+")
    $stdout = tmp
    i = IO.popen("/usr/sbin/xfs_quota -x -c \"quot -un -b\" #{x.split(/ /)[0]}","w+")
    puts i.readlines
    i.close
  end
end
$stdout = old_out

# Iterate over file systems and populate Hashes
file_systems.each do |x|
  mpoint = x.split(/ /)[0]
  type = x.split(/ /)[1]
  if type == "lustre"
    stats.each_key do |uid|
      tmp = IO.popen("lfs quota -u #{uid} #{mpoint}")
      proctemp += tmp.readlines
      tmp.close
      proctemp = proctemp.drop(2)
      stats[uid][mpoint] = ((proctemp[0].to_s.strip.split(/ /)[1].to_f / 1024) / 1024)
      proctemp.clear
    end
  end
  if type == "xfs"
    File.open("/tmp/xfs_details.txt","r").each do |tfile|
      unless tfile =~ /^[^0-9 ]/
        size = ((tfile.strip.split(/\s+/)[0].to_f / 1024) / 1024)
        user = tfile.strip.split(/\s+/)[1].gsub("#",'').chomp
        if stats.has_key?(user)
          stats[user][mpoint] = size
        end
      end
    end
  end
end

# Re-establish DB connection and populate proper columns
dbconn = PG::Connection.open(dbstr)
stats.each_key do |uid|
  stats[uid].each_key do |mp|
    mp.match(/^.*\W(.*)$/)
    for i in 0...coltemp.length 
      if coltemp[i][0] == $1 
        #puts "uid: #{uid} fs: #{mp} size: #{stats[uid][mp]} dbcol: #{coltemp[i][1]}"
        u_query = dbconn.exec("update cwa_user_metrics set #{coltemp[i][1]} = '#{stats[uid][mp]}' where user_id = '#{uid}'")
        rows += u_query.cmdtuples()
      end
    end
  end
end
dbconn.close

puts "Total table updates: #{rows}"
system("rm /tmp/xfs_details.txt")
