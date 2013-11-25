class User #{{{
#  public    :id, :parent=(newOu), :familyName, :givenName, :eMail, :yearGroup, :groups, :save, :delete
#  protected 
#  private   :shouldBeInGroup, :exists, :create, :update
  @@users = {}
  def User.exists?(dn)
    @@users[dn] if @@users[dn]
  end
  def initialize(dn) #{{{
    @@users[dn] = self
    @dn = dn
#    @ou
#    @samid
    @upn
    @fn
    @newFn
    @ln
    @newLn
    @yearGroup
    @newYearGroup
    @hmdir
    @groups = {}
    @newGroups = []
    if exists?
#      puts 'User exists in AD'
      user_cmd = 'dsget user "' + @dn + '" -fn -ln'
      result = %x{#{user_cmd}}.split("\n")[1].split
#      @samid = result[0].to_s
#      @upn = result[1].to_s
      @fn = result[0].to_s
      @ln = result[1].to_s
      group_cmd = 'dsget user "' + @dn + '" -memberof'
      groups = %x{#{group_cmd}}.split("\n")
      groups.each do |group|
        group.gsub!('"','')
        if Group.exists?(group)
          @groups[group] = Group.exists?(group)
        else
          @groups[group] = Group.new(group)
        end
      end
    end
  end #}}}
  def to_s
    "User:- @dn:#{@dn} - @upn:#{@upn} - samid:#{samid} - @newFn:#{@newFn} - @newLn:#{@newLn} - @fn:#{@fn} - @ln:#{@ln} - @hmdir:#{@hmdir} - @groups:#{@groups} - @newGroups:#{@newGroups}"
  end
  def dn
    @dn
#    "CN=#{@samid},#{@ou.dn}"
  end
  def parent
    dnParts = @dn.split(',')
    dnParts.delete_at(0)
    dnParts.join(',')
  end
  def samid
    dnParts = @dn.split(',')[0].split('=')[1]
  end
  def uid=(newUid)
    @samid = newUid
  end
  def parent=(newOu)
    if OU.exists?(newOu) then
      @ou = OU.exists?(newOu)
    else
      @ou = OU.new(newOu)
    end
  end
  def familyName=(newLn)
    @newLn = newLn
  end
  def givenName=(newFn)
    @newFn = newFn
  end
  def eMail=(newUpn)
    @upn = newUpn
  end
  def yearGroup=(newYearGroup)
    @newYearGroup = newYearGroup
  end
  def addGroup=(newGroup)
    if Group.exists?(newGroup) then
      @newGroups << Group.exists?(newGroup)
    else
      @newGroups << Group.new(newGroup)
    end
  end
  def groups=(newDesiredGroups)
    @newGroups = newDesiredGroups
  end
  private
  def shouldBeInGroup?(group)
    true if @newGroups.include? group
  end
  def exists?
    cmd = 'dsquery user "' + @dn + '" -o dn'
#    puts cmd
    true if %x{#{cmd}}.include?(@dn)
  end
  public
  def save
    if exists? then
      update
    else
      create
    end
    if @groups
      @groups.each do |group|
        if ! shouldBeInGroup?(group)
          group.removeMember(self)
        end
      end
    end
    if @newGroups
      @newGroups.each do |group|
        if ! group.isMember?(self)
          group.addMember(self)
        end
      end
    end
  end
  private
  def create
    cmd = 'dsadd user "' + @dn + '" -samid "' + samid + '" -upn "' + @upn + '" -pwd "password" -fn "' + @newFn + '" -ln "' + @newLn + '" -mustchpwd yes -display "' + @newFn + ' ' + @newLn + '" -hmdir "\\\\wildfire\\homes\My Documents" -hmdrv U: -disabled no'
    puts cmd
#    cmd = '"C:/Program Files/Grsync/bin/ssh.exe" -i "C:/ProgramData/ssh/id_rsa" -o UserKnownHostsFile="C:/ProgramData/ssh/known_hosts" root@wildfire \'/mnt/fs/provision_user_storage_and_profile -u "' + @samid + '" -p "Faculty" -y "' + year_of_entry( year ) + '" -d "STOWMARKETM"\''
#    puts cmd
  end
  def update
    cmd = 'dsmod user "' + dn + '"'
    cmd << ' -fn "' + @newFn + '"' if @newFn != @fn
    cmd << ' -ln "' + @newLn + '"' if @newLn != @ln
    cmd << ' -display "' + (@newFn ? @newFn : @fn) + ' ' + (@newLn ? @newLn : @ln) + '"' if (@newFn != @fn) or (@newLn != @ln)
    puts cmd
  end
  public
  def delete
    if exists? then
      if @groups != nil
        @groups.each do |group|
          group.removeMember(self)
        end
      end
      cmd = 'dsrm ' + dn + ' -noprompt'
      puts cmd
    end
  end
end #}}}

class Group #{{{
  @@groups = {}
  def Group.exists?(dn)
    if @@groups[dn] then
      @@groups[dn]
    else
      false
    end
  end
  def initialize(dn)
    @@groups[dn] = self
    @dn = dn
    @members = members
    if ! OU.exists?(parent) and OU.is_ou?(parent) then
      OU.new(parent)
    end
  end
  def parent
    dnParts = @dn.split(',')
    dnParts.delete_at(0)
    dnParts.join(',')
  end
  def name
    dnParts = @dn.split(',')[0].split('=')[1]
  end
  def dn
    @dn
  end
  def create
    cmd = 'dsadd group "' + @dn + '"'
    puts cmd
  end
  def destroy
    cmd = 'dsrm group "' + @dn + '" -noprompt'
    puts cmd
  end
  def members
    cmd = 'dsget group "' + @dn + '" -members'
#    puts cmd
    result = %x{#{cmd}}
    users = {}
    if result.split.count == 0
      users
    else
      userDns = result.split("\n")
      userDns.each do |userDn|
        userDn.gsub!('"','')
        if User.exists?(userDn)
          users[userDn] = User.exists?(userDn)
        else
          users[userDn] = User.new(userDn)
        end
      end
    end
  end
  def isMember?(u)
    true if @members.include?(u)
  end
  def addMember(u)
    cmd = 'dsmod group "' + @dn + '" -addmbr "' + u.dn + '"'
    puts cmd
  end
  def removeMember(u)
    cmd = 'dsmod group "' + @dn + '" -rmmbr "' + u.dn + '"'
    puts cmd
  end
end #}}}

class OU #{{{
  @@base = 'DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
  @@ous = {}
  def OU.exists?(dn)
    if @@ous[dn] then
      @@ous[dn]
    else
      false
    end
  end
  def OU.is_ou?(ou)
    type = ou.split('=')[0]
    true if type == 'OU'
  end
  def OU.list_ous
    @@ous.each do |ou|
      puts ou
    end
  end
  def initialize(dn)
    @@ous[dn] = self
    @dn = dn
    @users
    @groups
    if ! @@ous[parent] and parent != @@base and OU.is_ou?(parent) then# != "CN=Users,#{@@base}" then
      OU.new(parent)
    end
  end
  def parent
    dnParts = @dn.split(',')
    dnParts.delete_at(0)
    dnParts.join(',')
  end
  def name
    dnParts = @dn.split(',')[0].split('=')[1]
  end
  def list_ous
    @@ous.each do |ou|
      puts ou
    end
  end
  def dn
    @dn
#    if @parent == false
#      "OU=#{@name},#{@@base}"
#    else
#      "OU=#{@name},#{@parent.dn}"
#    end
  end
  def create
  end
  def destroy
  end
  def membersUsers
  end
  def memberGroups
  end
end #}}}

#class OU
#  @@base = 'DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
#  def initialize(name, parent=false)
#    @name = name
#    @parent = parent
#    @users
#    @groups
#  end
#  def dn
#    if @parent == false
#      "OU=#{@name},#{@@base}"
#    else
#      "OU=#{@name},#{@parent.dn}"
#    end
#  end
#  def create
#  end
#  def destroy
#  end
#  def membersUsers
#  end
#  def memberGroups
#  end
#end

#year5 = OU.new('OU=13,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
#year6 = OU.new('OU=12,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
#year7 = OU.new('OU=11,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
#year8 = OU.new('OU=10,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
#puts year8.name
#puts year8.parent
#puts year8.list_ous
#puts OU.exists?('OU=14,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
#students = OU.new('OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
#puts "Students: #{students}"
#puts year8.list_ous

##ouGroups = OU.new('Groups')
##puts ouGroups.dn
##ouGroupsUser = OU.new('User', ouGroups)
##puts ouGroupsUser.dn
#gYear5 = Group.new('CN=Year5,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
##puts gYear5.inspect
##puts gYear5.dn
##
##ouUserAccounts = OU.new('User Accounts')
##ouStudents = OU.new('Students', ouUserAccounts)
##ouYear5 = OU.new('13', ouStudents)
##
#users = {}
#users['Another'] = User.new('CN=AUser,OU=13,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
##puts users['Another'].inspect
#users['Another'].givenName = 'Another'
#users['Another'].familyName = 'User'
#users['Another'].eMail = 'auser@stowmarketmiddle.suffolk.sch.uk'
##users['Another'].uid = 'AUser'
#users['Another'].yearGroup = 5
##users['Another'].parent = 'OU=13,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
##users['Another'].addGroup = 'CN=Year_5,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
##users['Another'].addGroup = 'CN=Domain Users,CN=Users,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
##users['Another'].addGroup = 'CN=13_Students,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
##users['Another'].addGroup = 'CN=Students,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
##users['Another'].addGroup = 'CN=MoodleUser,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
##users['Another'].addGroup = 'CN=InternetAuthStudents,OU=User,OU=Groups,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
##puts users['Another'].inspect
##puts users['Another'].to_s
##users['Another'].save
##users['Another'].delete
##puts OU.list_ous
#users['08'] = User.new('CN=08,OU=08,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')# if User.exists?('CN=08,OU=08,OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
#puts '-----'
#puts 'users[\'08\'].to_s:'
#puts users['08'].to_s
#puts '-----'
##puts OU.list_ous
#puts '-----'
#puts 'users.to_s:'
#puts users.to_s
#puts '-----'
#puts 'users.inspect:'
#puts users.inspect
##puts ''
##puts OU.exists?('OU=Students,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk')
#puts '-----'
#OU.list_ous
##puts ''
##puts users['Another'].inspect

def loadStaffData #{{{
  u = {}
  j = -1
  File.open( 'ReportOutput.txt' ).each do |line|
    i = -1
    line.split("\t").each do |field|
      i += 1
      case i
        when 0
          next if field == ''
          # Title
          j += 1
  #        next if j == 0
          u[j] = {}
  #        u[j]['classes'] = []
          u[j]['subjects'] = []
          u[j]['title'] = field
        when 1
          next if field == ''
          # Family Name
          u[j]['ln'] = field
        when 2
          next if field == ''
          u[j]['fn'] = field
        when 3
          next if field == ''
          u[j]['staffCode'] = field.strip
        when 4
          next if field == ''
          u[j]['staffType'] = field
        when 5
          next if field == '' or field == "\r\n"
  #        u[j]['classes'] << field.gsub("\r\n", '')
          subject = ''
          case field.gsub("\r\n", '').gsub(/^.*\//, '').gsub(/[0-9]$/, '')
            when 'Ar'#
              subject = 'Art'
            when 'En'
              subject = 'English'
            when 'Ma'
              subject = 'Maths'
            when 'Sc'
              subject = 'Science'
            when 'H'
              subject = 'History'
            when 'It'
              subject = 'ICT'
            when 'Te'#
              subject = 'Design & Technology'
            when 'Fr'
              subject = 'French'
            when 'Mu'
              subject = 'Music'
            when 'Pe'
              subject = 'Physical Education'
            when 'Re'
              subject = 'Religious Education'
            when 'Ps'
              subject = 'PSHE'
            when 'G'
              subject = 'Geography'
          end
          next if subject == '' or  u[j]['subjects'].include? subject
          u[j]['subjects'] << subject
        else
          # Do Nothing
      end
    end
  end
  u
end #}}}

def loadStudentData #{{{
end #}}}

class String
  def initial
    self[0,1]
  end
end

staff = loadStaffData()

users = {}

staff.each do |s| #{{{
  next if s[1]['staffCode'] == nil or s[1]['staffCode'] == 'Staff Code'
  next unless s[1]['staffType']
  puts s[1]['staffCode'] + ' : ' + s[1]['fn'] + ' ' + s[1]['ln']
  dn = ''
  case s[1]['staffType']
    when 'Teacher'
      dn = 'CN=' + s[1]['staffCode'].downcase + ',OU=Teacher,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
    when 'Administrative (A-Team)'
      dn = 'CN=' + s[1]['fn'].initial.downcase + s[1]['ln'].downcase + ',OU=A Team,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
    when 'I.T. Services'
      dn = 'CN=' + s[1]['fn'].initial.downcase + s[1]['ln'].downcase + ',OU=IT Services,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
    when 'Teaching Assistant'
      dn = 'CN=' + s[1]['fn'].initial.downcase + s[1]['ln'].downcase + ',OU=TAs,OU=User Accounts,DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk'
  end
  puts dn
#  users[dn] = User.new(dn)
end #}}}
