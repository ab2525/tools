#!/usr/bin/env bash
#MAKE SURE ALL THE TXT FILES ARE CORRECT
#BEFORE RUNNING THIS SCRIPT
#must be run as root
#Text files needed:
#iptables.sh - will be a script containing the iptables rules you want
#netconfig.txt - containing the interface config - must be changed to match network setup
#
####################################################################################
#THINGS TO CHECK ######################################
#if setting immutable flag to /boot and making it read only screws up box. if not, do dat in dis

#if not 1 param
if [ $# -ne 1 ]
   then 
      set "eth0"
      echo "expected name of main interface, but automatically assumed to be 'eth0'"
fi

#setting the net int down
ifconfig down $1

outfile=info.txt #set output file

#cronjobs aka blowjob
crontab -r
mv /etc/crontab /etc/.crontab.bak
mv /etc/anacrontab /etc/.anacrontab.bak

#edit sudoers
mv /etc/sudoers /etc/.sudoers.bak
echo " " > /etc/sudoers
chmod 000 /etc/sudoers
chattr +i /etc/sudoers

#calling iptables script to set all the ip tables rules
./iptables.sh &

function fix_repo {
	if [ ! -e $2 ]; then
		return 1
	fi
	if [ "$1" == "apt" ]; then
		mv /etc/apt/sources.list /etc/apt/sources.list.bak
		cp $2 /etc/apt/sources.list
		chattr +i /etc/apt/sources.list
		chattr +i /etc/apt
	elif [ "$1" == "yum" ]; then
		repos=`ls /etc/yum.repos.d`
		for f in $repos; do
			mv $f $f.bak
		done
		cp $2 /etc/yum.repos.d/default.repo
		chattr +i /etc/yum.repos.d/default.repo
		chattr +i /etc/yum.repos.d
	elif [ "$1" == "emerge" ]; then
		echo "$1 fix_repo feature not yet implemented"
	fi
}

#determine distro to get package manage and int config location
if [ -f /etc/redhat-release ] ; then
	pkmgr=`which yum`
	sys_netconfig="/etc/sysconfig/network-scripts/ifcfg-$1"
	fix_repo yum repos.txt # do repo stuff
elif [ -f /etc/debian_version ] ; then
	pkmgr=`which apt-get`
	sys_netconfig="/etc/network/interfaces"
	fix_repo apt repos.txt # do repo stuff
elif [ -f /etc/gentoo_version ]; then #possible might need this too: -f /etc/gentoo-release
	pkmgr=`which emerge`
	ln -s /etc/init.d/net.lo /etc/init.d/net.$1 #create link so system recognizes net.lo file. needed for manual net config
	sys_netconfig="/etc/conf.d/net"
	#still need to figure out
	fix_repo emerge repos.txt # do repo stuff
elif [ -f /etc/slackware-version ]; then
	pkmgr=`which installpkg`
	sys_netconfig="/etc/rc.d/rc.inet1.conf"
	fix_repo apt repos.txt # do repo stuff
else
	echo "OS/distro not detected...using debian defaults..." >&2
	pkmgr=`which apt-get` #if can't find OS, just use apt-get and hope for best
	sys_netconfig="/etc/network/interfaces"
	fix_repo apt repos.txt # do repo stuff
fi

#set static ip address and do network interface config stuff
#sys_netconfig="/etc/network/interfaces"
netconfig=netconfig.txt

if [ -e $netconfig ]; then
	cp $sys_netconfig $sys_netconfig.backup
	cat $netconfig > $sys_netconfig
else
	echo "no network config file given. interface may not be configured properly" >&2
fi

#set hosts file location and do hosts file securing
hosts="/etc/hosts"

cp $hosts $hosts.backup
echo "127.0.0.1       localhost" > $hosts
echo "127.0.1.1       `hostname`" >> $hosts
chattr +i $hosts
chmod 600 $hosts

#linux kernel hardening - /etc/sysctl.conf - buie?

#disk quotas - buie?

#put the interface back up ifconfig up $1
ifconfig up $1

#upgrading and updating everything
$pkmgr update & disown > .updateinfo.txt
$pkmgr upgrade -y & disown > .upgradeinfo.txt

#makes the jail. if /var/jail taken, somewhat random directory attempted to be made in hopes it doesn't exist
if [ ! -e /var/jail ]; then
	./jail_maker.sh -s /var/jail &
elif [ ! -e /var/jm_jail_5186 ]; then
	./jail_maker.sh -s /var/jm_jail_5186 &
else
	echo "jail not made. must pick a new directory" >&2
fi

#Make Sure No Non-Root Accounts Have UID Set To 0
echo "Accounts with UID = 0" >> $outfile
echo `awk -F: '($3 == "0") {print}' /etc/passwd` >> $outfile
echo "" >> $outfile

#all listening ports
echo "All the ports that you're listening on" >> $outfile
echo `lsof -nPi | grep -iF listen` >> $outfile
echo "" >> $outfile

#finding all of the world-writeable files
echo "All of the world-writable files" >> $outfile
find / -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print >> $outfile
echo "" >> $outfile

#finding all of the no owner files
echo "All of the no owner files" >> $outfile
find / -xdev \( -nouser -o -nogroup \) -print >> $outfile
echo "" >> $outfile

#prompt for ssh box
read -p "is this an ssh box (Y/N): " answer
answer=`echo $answer | tr '[:lower:]' '[:upper:]'`
if [ "$answer" == "Y" ]; then
	./ssh.sh &
fi

#prompt for web box
#web.sh does not exist yet
read -p "is this a web box (Y/N): " answer
answer=`echo $answer | tr '[:lower:]' '[:upper:]'`
if [ "$answer" == "Y" ]; then
	./web.sh &
fi



