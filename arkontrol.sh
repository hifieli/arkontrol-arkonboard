#!/sbin/sh
###############################################################################
#
#  ARKonBoard - a script for Installing a dedicated ARK server onto a
#                   new dedicated server or cloud server.
#
#             - part of arkontrol. For more information, please visit
#                   http://arkcontrol.com
#
###############################################################################
#
#  version: 0.1.0design
#  date:    July 6, 2015
#  author:  hifieli <hifieli2@gmail.com>
#
###############################################################################
#
#  This script is to be run as soon as you login via SSH the first time.
#	Tested with Ubuntu 14.04 LTS
#
###############################################################################


PROJNAME="ARKonBoard"
PROJVER="0.1.0design"
PROJAUTH="hifieli <hifieli2@gmail.com>"


###############################################################################
# Gameplan
###############################################################################
#	prep system
#		create user
#		modify file limits, etc
#	install ARK server
#	install web panel
#		install lighttpd+PHP
#		place PHP sources
#	configs
#		upstart file for ARK server
#		iptables - SSH ports, ftp ports, httpd ports, and ark ports
#
###############################################################################

###############################################################################
# Planned improvements:
###############################################################################
#	FTP server
#	SSH port change
#	iptables hardening
#	test with systemd script on 15.04
#	check into CentOS compat
#	munin?
###############################################################################


# Maybe we should get this from the user interactively, or at least allow it to
# be specified on the command line.
WEBADMIN="admin"
WEBPASS="admin"


###############################################################################
# Root Check (Don't be root, please. If you are, well, get hacked.)
###############################################################################
###############################################################################
cd ~
MYHOME=`pwd`

if [ MYHOME == "/root" ]; then
        ln -s /root /home/root
fi


###############################################################################
# Prep System
###############################################################################
###############################################################################

#------------------------------------------------------------------------------
# Install required libs
#------------------------------------------------------------------------------
sudo apt-get install lib32gcc1 -y
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Create a user for our server
#------------------------------------------------------------------------------
touch /tmp/shells.tmp.ARKonBoard
sudo cat /etc/shells | grep -v "/usr/sbin/nologin" > /tmp/shells.tmp.ARKonBoard
sudo echo "/usr/sbin/nologin" >> /tmp/shells.tmp.ARKonBoard
sudo mv /etc/shells /etc/shells.bak
sudo mv /tmp/shells.tmp.ARKonBoard /etc/shells
sudo useradd -m steam -s /usr/sbin/nologin
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Modify file limits, etc
#    http://ark.gamepedia.com/Dedicated_Server_Setup
#------------------------------------------------------------------------------
#  1. Modify /etc/sysctl.conf:
touch /tmp/sysctl.conf.tmp.ARKonBoard
sudo cat /etc/sysctl.conf | grep -v "fs.file-max=100000" > /tmp/sysctl.conf.tmp.ARKonBoard
sudo echo "fs.file-max=100000" >> /tmp/sysctl.conf.tmp.ARKonBoard
sudo mv /etc/sysctl.conf /etc/sysctl.conf.bak
sudo mv /tmp/sysctl.conf.tmp.ARKonBoard /etc/sysctl.conf

#  2. Apply the change:
sudo sysctl -p /etc/sysctl.conf

#  3. Modify /etc/security/limits.conf:
touch /tmp/security-limits.conf.tmp.ARKonBoard
sudo cat /etc/security/limits.conf | grep -v "`cat /etc/security/limits.conf | tail -n1`" | grep -v "*               soft    nofile          1000000" | grep -v "*               hard    nofile          1000000" > /tmp/security-limits.conf.tmp.ARKonBoard
sudo echo "*               soft    nofile          1000000" >> /tmp/security-limits.conf.tmp.ARKonBoard
sudo echo "*               hard    nofile          1000000" >> /tmp/security-limits.conf.tmp.ARKonBoard
sudo echo "# End of file" >> /tmp/security-limits.conf.tmp.ARKonBoard
sudo mv /etc/security/limits.conf /etc/security/limits.conf.bak
sudo mv /tmp/security-limits.conf.tmp.ARKonBoard /etc/security/limits.conf

#  4. Modify /etc/pam.d/common-session:
touch /tmp/pam.d-common-session.tmp.ARKonBoard
sudo cat /etc/pam.d/common-session | grep -v "session required pam_limits.so" > /tmp/pam.d-common-session.tmp.ARKonBoard
sudo echo "session required pam_limits.so" >> /tmp/pam.d-common-session.tmp.ARKonBoard
sudo cp /etc/pam.d/common-session /etc/pam.d/common-session.bak
sudo mv /tmp/pam.d-common-session.tmp.ARKonBoard /etc/pam.d/common-session
#------------------------------------------------------------------------------


###############################################################################
# Install Web Panel
###############################################################################
###############################################################################

#------------------------------------------------------------------------------
# Install ligHTTPd and php5.
#------------------------------------------------------------------------------
sudo aptitude install lighttpd php5-cgi -y
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Enable fastcgi module so they can work together.
#------------------------------------------------------------------------------
sudo lighttpd-enable-mod fastcgi
sudo lighttpd-enable-mod fastcgi-php
sudo service lighttpd force-reload
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Allow webserver to manipulate services (yeah, this is NOT ideal)
#------------------------------------------------------------------------------
touch /tmp/etc-sudoers.tmp.ARKonBoard
sudo cat /etc/sudoers | grep -v "www-data ALL=(ALL) NOPASSWD: ALL" > /tmp/etc-sudoers.tmp.ARKonBoard
sudo echo "www-data ALL=(ALL) NOPASSWD: ALL" >> /tmp/etc-sudoers.tmp.ARKonBoard
sudo cp /etc/sudoers /etc/sudoers.bak
sudo mv /tmp/etc-sudoers.tmp.ARKonBoard /etc/sudoers
#------------------------------------------------------------------------------




#------------------------------------------------------------------------------
# Obtain PHP sources
#   In the future, move this to github
#------------------------------------------------------------------------------
cd /var/www
sudo wget http://cdn.arkontrol.com/arkontrol-php.tar
sudo tar -xvzf arkontrol-php.tar --overwrite
sudo rm -f arkontrol-php.tar
sudo chmod 777 /var/www/includes/smarty/templates_c/
sudo mv /var/www/arkontrol.ini /etc/arkontrol.ini
sudo chmod 777 /etc/arkontrol.ini
sudo chown -R www-data:www-data /var/www
sudo curl --silent 127.0.0.1 > /dev/null
#------------------------------------------------------------------------------



###############################################################################
# Install ARK server 
#   This section adopted from the official tutorial
#   https://developer.valvesoftware.com/wiki/SteamCMD#Linux
###############################################################################
###############################################################################
mkdir ~/steamcmd
wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz -O ~/steamcmd/steamcmd_linux.tar.gz
cd ~/steamcmd
tar -xvzf ~/steamcmd/steamcmd_linux.tar.gz
sudo mv ~/steamcmd /home/steam/steamcmd
sudo chown -R steam:steam /home/steam/steamcmd

# It's about to get really dirty.
MYEXITCODE=1
while [ $MYEXITCODE -ne 0 ]; do
	sudo -u steam /home/steam/steamcmd/steamcmd.sh +login anonymous +force_install_dir ../ark_ds +app_update 376030 +quit
	MYEXITCODE=$?
	# It doesn't always complete successfully, 
done

#------------------------------------------------------------------------------




###############################################################################
# Configs
###############################################################################
###############################################################################


#------------------------------------------------------------------------------
# Create Upstart config
#   /etc/init/ark-dedicated.conf
#------------------------------------------------------------------------------
touch /tmp/ark-dedicated.conf
sudo echo "# Generated by ${PROJNAME} ${PROJVER} at `date`" > /tmp/ark-dedicated.conf
sudo echo "" >> /tmp/ark-dedicated.conf
sudo echo "description \"ark-dedicated\"" >> /tmp/ark-dedicated.conf
sudo echo "" >> /tmp/ark-dedicated.conf
sudo echo "setuid steam" >> /tmp/ark-dedicated.conf
sudo echo "" >> /tmp/ark-dedicated.conf
sudo echo "respawn" >> /tmp/ark-dedicated.conf
sudo echo "respawn limit 15 5" >> /tmp/ark-dedicated.conf
sudo echo "" >> /tmp/ark-dedicated.conf
sudo echo "start on runlevel [2345]" >> /tmp/ark-dedicated.conf
sudo echo "stop on runlevel [06]" >> /tmp/ark-dedicated.conf
sudo echo "" >> /tmp/ark-dedicated.conf
sudo echo "script" >> /tmp/ark-dedicated.conf
sudo echo "    echo \$\$ > /tmp/ark_ds.pid" >> /tmp/ark-dedicated.conf
sudo echo "    exec /home/steam/ark_ds/ShooterGame/Binaries/Linux/ShooterGameServer TheIsland?listen -server -log" >> /tmp/ark-dedicated.conf
sudo echo "end script" >> /tmp/ark-dedicated.conf
sudo echo "" >> /tmp/ark-dedicated.conf
sudo echo "pre-start script" >> /tmp/ark-dedicated.conf
sudo echo "    echo \"[\`date\`] ARK Dedicated Server Starting\" >> /home/steam/Steam/logs/ark_ds.log" >> /tmp/ark-dedicated.conf
sudo echo "end script" >> /tmp/ark-dedicated.conf
sudo echo "" >> /tmp/ark-dedicated.conf
sudo echo "pre-stop script" >> /tmp/ark-dedicated.conf
sudo echo "    rm /tmp/ark_ds.pid" >> /tmp/ark-dedicated.conf
sudo echo "    echo \"[\`date\`] ARK Dedicated Server  Stopping\" >> /home/steam/Steam/logs/ark_ds.log" >> /tmp/ark-dedicated.conf
sudo echo "end script" >> /tmp/ark-dedicated.conf
sudo mv /tmp/ark-dedicated.conf /etc/init/ark-dedicated.conf
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Open Firewall Ports
#------------------------------------------------------------------------------
# SSH port
sudo iptables -I INPUT -p tcp --dport 9022 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 22 -j ACCEPT

# web port(s)
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT

# ARK Dedicated Server ports
sudo iptables -I INPUT -p udp --dport 27015 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 27015 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 27016 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 27016 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 7778 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 7778 -j ACCEPT

#------------------------------------------------------------------------------
# TODO: do something to make sure all the ports are still open after a reboot
#------------------------------------------------------------------------------



###############################################################################
# Start the ARK server!!
/home/steam/ark_ds/ShooterGame/Binaries/Linux/ShooterGameServer TheIsland?listen -server -log &
sleep 3
killall -9 ShooterGameServer
sleep 5
sudo mv ~/Steam /home/steam/Steam
if [ ! -d /home/steam/Steam/logs ]; then
	mkdir /home/steam/Steam/logs
fi
sudo chown -R steam:steam /home/steam/Steam
sudo service ark-dedicated restart
sudo chmod 666 /home/steam/ark_ds/ShooterGame/Saved/Config/LinuxServer/*
###############################################################################
###############################################################################

echo "\n\n\tInstallation of ${PROJNAME} has completed. To manage your server, "
echo "\tpoint your browser to the server's IP address:\n"
MYIP=`curl cidr.pw/ip`
echo "\t\t http://${MYIP}"
echo "\n\tThe username / password is set to ${WEBADMIN} / ${WEBPASS}"
echo "\tPlease change the password first thing after you login.\n"
#------------------------------------------------------------------------------