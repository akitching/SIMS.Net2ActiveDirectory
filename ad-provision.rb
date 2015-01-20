#!/usr/bin/ruby

require 'fileutils'
require 'rexml/document'
require 'pp'
require 'optparse'

options = {}

options[:file] = false
options[:command] = 'C:\Program Files\SIMS\SIMS .net\CommandReporter.exe'
options[:dryrun] = false
options[:debug] = false
optparse = OptionParser.new { |opts|

  opts.on( '-h', '--help', 'Usage information' ) do
    puts opts
    exit
  end

  opts.on( '-u', '--user USERNAME', 'SIMS Username' ) do |u|
    options[:user] = u
  end
  opts.on( '-p', '--password PASSWORD', 'SIMS Password' ) do |p|
    options[:password] = p
  end
  opts.on( '-r', '--report REPORT', 'SIMS Report Name' ) do |r|
    options[:report] = r
  end
  opts.on( '-f', '--file FILE', 'Filename of cached report' ) do |f|
    options[:file] = f
  end
  opts.on( '-c', '--command COMMAND_PATH', 'SIMS CommandReporter binary' ) do |c|
    options[:command] = c
  end
  opts.on( '-n', '--dry-run', 'Dry run. Report what would be done but make no changes' ) do |n|
    options[:dryrun] = n
  end
  opts.on( '-d', '--debug', 'Increase output.' ) do |d|
    options[:debug] = d
  end
}

begin
  optparse.parse!
  if options[:file] == false                                      # Skip checks if file is set
    mandatory = [:user, :password, :report]                       # Enforce the presence of
    missing = mandatory.select{ |param| options[param].nil? }     # the -t and -f switches
    if not missing.empty?                                         #
      puts "Missing options: #{missing.join(', ')}"               #
      puts optparse                                               #
      exit                                                        #
    end                                                           #
  end                                                             #
rescue OptionParser::InvalidOption, OptionParser::MissingArgument #
  puts $!.to_s                                                    # Friendly output when parsing fails
  puts optparse                                                   #
  exit                                                            #
end

$dryrun = options[:dryrun]
$debug = options[:debug]

$f = File.open('c:\User_Provision\ad-provision.log', 'w')

def year_of_entry(data)
  yeargroup = data.to_i
  time = Time.new
  year = nil
  if time.month < 9
    year = time.year - yeargroup.to_i + 4
  else
    year = time.year - yeargroup.to_i + 5
  end
  year.to_s.sub( /^[0-9]{2}/, '' )
end

def year_group(data)
  year = data.to_i
  time = Time.new
  yeargroup = nil
  if time.month < 9
    yeargroup = time.year + year.to_i - 4
  else
    yeargroup = time.year + year.to_i - 5
  end
end

def add_ou(dn)
  if dn.include? '"'
    ouadd = 'dsadd ou ' + dn
  else
    ouadd = 'dsadd ou "' + dn + '"'
  end
  $f.write(ouadd + "\n")
  if $dryrun == false
    %x{#{ouadd}}
  end
  if dn =~ /^\"CN=([0-9]{2}).*\"$/ #{
    year = dn.sub(/^\"CN=([0-9]{2}).*\"$/, '\1')
    group_list = Array.new
    group_list << "CN=Domain Users,CN=Users,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
    group_list << "CN=" + year + "_Students,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
    group_list << "CN=Year_" + year_group( year) + ",OU=VLE,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
    group_list << "CN=Students,OU=VLE,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
    group_list << "CN=MoodleUser,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
    group_list << "CN=InternetAuthStudents,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
    active_users << add_user(year, year_group( year ), 'Test', 'Pupil', group_list)
  end #}
end

def del_ou(dn)
  if dn.include? '"'
    oudel = 'dsrm ' + dn + ' -noprompt'
  else
    oudel = 'dsrm "' + dn + '"' + ' -noprompt'
  end
  $f.write(oudel + "\n")
  if $dryrun == false
    %x{#{oudel}}
  end
end

def add_user(userid, year, givenname, familyname, groups)
  oudn = 'OU=' + year_of_entry( year ) + ',OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
  result = %x{dsquery ou "#{oudn}" -q}
  if ! result.include? oudn
    add_ou(oudn)
  end
  dn = '"CN=' + userid + ',' + oudn + '"'
  useradd = 'dsadd user ' + dn + ' -samid "' + userid + '" -upn "' + userid + '@students.stowmarketmiddle.suffolk.sch.uk" -pwd "password" -fn "' + givenname + '" -ln "' + familyname + '" -mustchpwd yes -display "' + givenname + ' ' + familyname + '"'
  useradd << ' -hmdir "\\\\wildfire\\homes\\My Documents" -hmdrv U: -disabled no'
  $f.write(useradd + "\n")
  if $dryrun == false
    %x{#{useradd}}
  end
  cmd = '"C:/Program Files/Grsync/bin/ssh.exe" -i "C:/ProgramData/ssh/id_rsa" -o UserKnownHostsFile="C:/ProgramData/ssh/known_hosts" root@wildfire \'/mnt/fs/provision_user_storage_and_profile -u "' + userid + '" -p "Faculty" -y "' + year_of_entry( year ) + '" -d "STOWMARKETM"\''
  $f.write(cmd + "\n")
  if $dryrun == false
    %x{#{cmd}}
  end
  dn
end

def del_user(dn)
  if dn.include? '"'
    cmd = 'dsrm ' + dn + ' -noprompt'
  else
    cmd = 'dsrm "' + dn + '"' + ' -noprompt'
  end
  $f.write(cmd + "\n")
  if $dryrun == false
    %x{#{cmd}}
  end
  oudn = dn.sub( /^CN=[^,]*,/, '' )
  users = %x{dsquery user #{oudn}}.split("\n")
  if users.count == 0
    del_ou(oudn)
  elsif ( users.count == 1 and users[0] == '"CN=' + dn.sub( /\"CN[^,]*,OU=([^,]*),.*\"$/, '\1') + ',' + oudn )
    del_user( '"CN=' + dn.sub( /\"CN[^,]*,OU=([^,]*),.*\"$/, '\1') + ',' + oudn )
  end
end

def add_to_group(gdn, users)
  result = %x{dsquery group "#{gdn}" -q}
  cmd = nil
  if result.include? gdn
    cmd = 'dsmod group ' + gdn + ' -addmbr'
  else
    cmd = 'dsadd group "' + gdn + '" -members'
  end
  users.each { |user|
    cmd << ' ' + user.chomp
  }
  $f.write(cmd + "\n")
  if $dryrun == false
    %x{#{cmd}}
  end
end

def remove_from_group(gdn, users)
  cmd = 'dsmod group ' + gdn + ' -rmmbr'
  users.each { |user|
      cmd << ' ' + user.chomp
  }
  $f.write(cmd + "\n")
  if $dryrun == false
    %x{#{cmd}}
  end
  result = %x{dsget group #{gdn} -members}
  if result.split.count == 0
    del_group(gdn)
  end
end

def del_group(gdn)
  cmd = 'dsrm ' + gdn + ' -noprompt'
  $f.write(cmd + "\n")
  if $dryrun == false
    %x{#{cmd}}
  end
end

i = 0
adgroups = Hash.new
newusers = Array.new
failed_users = Array.new
active_users = Array.new

if options[:file] != false
  file = File.new options[:file]
  doc = REXML::Document.new file
else
  xml_data = %x{#{options[:command]} /USER:#{options[:user]} /PASSWORD:#{options[:password]} /REPORT:#{options[:report]} /QUIET}
  doc = REXML::Document.new(xml_data)
end
doc.elements.each( 'SuperStarReport/Record' ) { |record|
  i = i + 1
  puts i unless $debug == false
  userid = record.elements['Adno'].text.sub( /^[0]*/, '' )
  puts "userid: " + userid unless $debug == false
  altuserid = record.elements['Legal_x0020_Surname'].text + '.' + record.elements['Forename'].text
  if record.elements['Year'].nil?
    # Invalid year - Skip
    $f.write("WARNING: Invalid YearGroup - UserID: " + userid + "\n")
    next
  end
  year = record.elements['Year'].text.sub( /Year  /, '' )
  if record.elements['Reg'].nil?
    # Invalid class - Skip
    $f.write("WARNING: Invalid Class - UserID: " + userid + "\n")
    next
  end
  formgroup = record.elements['Reg'].text
  group_list = Array.new
  group_list << "CN=Domain Users,CN=Users,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  group_list << "CN=" + year_of_entry( year.to_i ) + "_Students,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  group_list << "CN=Year_" + year + ",OU=VLE,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  group_list << "CN=" + formgroup + ",OU=FormGroups,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  if !record.elements['House'].nil?
    house = record.elements['House'].text.sub( 'Townsend', 'Townshend' )
    group_list << "CN=" + house + ",OU=Houses,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  end
  group_list << "CN=Students,OU=VLE,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  group_list << "CN=MoodleUser,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  if !record.elements['Parental_x0020_Consent'].nil? and !record.elements['Parental_x0020_Consent'].text.nil? and record.elements['Parental_x0020_Consent'].text.include? 'Internet Access' and !record.elements['Internet_x0020_Ban'].text.include? 'True'
    group_list << "CN=InternetAuthStudents,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  end
  if record.elements['Pupil_x0020_Librarian'].text.include? 'True'
      group_list << "CN=Pupil_Librarians,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk"
  end

  dn = %x{dsquery user -samid #{userid}}.chomp
  if dn == '' #{
    dn = %x{dsquery user -samid "#{altuserid}"}.chomp
    if dn == ''
      if record.elements['Legal_x0020_Surname'].text.include? '-'
        dn = %x{dsquery user -samid "#{record.elements['Legal_x0020_Surname'].text.split( '-' )[0].strip}.#{record.elements['Forename'].text}"}.chomp
        if dn == ''
          dn = %x{dsquery user -samid "#{record.elements['Legal_x0020_Surname'].text.split( '-' )[1].strip}.#{record.elements['Forename'].text}"}.chomp
        end
      else
        dn = %x{dsquery user -samid "#{altuserid}1"}.chomp
      end
    end
  end #}
  if dn == '' #{
    puts 'Adding new user: ' + userid unless $debug == false
    $f.write('Adding new user: ' + userid + "\n")
    dn = add_user(userid, year.to_i, record.elements['Forename'].text, record.elements['Legal_x0020_Surname'].text, group_list)
    $f.write('== ' + dn + ' ==' + "\n")
  end #}
  active_users << dn
  groups = %x{dsget user #{dn} -memberof}
  groups = groups.gsub( '"', '' ).split( "\n" ).sort

  groups_to_add = group_list - groups
  groups_to_rm = groups - group_list
  groups_to_rm.each { |group|
    if ! adgroups.has_key? group
      adgroups[group] = Hash.new
    end
    if ! adgroups[group].has_key? 'rm'
      adgroups[group]['rm'] = Array.new
    end
    adgroups[group]['rm'] << dn
  }
  groups_to_add.each { |group|
    if ! adgroups.has_key? group
      adgroups[group] = Hash.new
    end
    if ! adgroups[group].has_key? 'add'
      adgroups[group]['add'] = Array.new
    end
    adgroups[group]['add'] << dn
  }
}

$f.write('Updating groups' + "\n")
puts "Updating groups" unless $debug == false
adgroups.each { |gdn, group|
  cmd = nil
  $f.write('Adding groups' + "\n")
  puts "Adding groups" unless $debug == false
  if group.has_key? 'add'
    add_to_group(gdn, group['add'])
  end
  $f.write('Removing groups' + "\n")
  puts "Removing groups" unless $debug == false
  if group.has_key? 'rm'
    remove_from_group(gdn, group['rm'])
  end
}

existing_users = Array.new
ous = %x{dsquery ou "OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk" -limit 1000}.split("\n")
ous.each { |ou|
  next unless ou =~ /^\"OU=[0-9]{2}/
  existing_users.concat(%x{dsquery user #{ou} -limit 1000}.split("\n"))
  active_users << '"CN=' + ou.sub( /\"OU=([0-9]{2}).*\"$/, '\1' ) + ',' + ou.gsub( '"', '' ) + '"'
}
inactive_users = existing_users - active_users

$f.write('Removing users' + "\n")
puts "Removing users" unless $debug == false
inactive_users.each { |user|
  $f.write(user)
  del_user( user )
}

$f.close
