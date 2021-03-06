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
#	install web panel
#		install lighttpd+PHP
#		place PHP sources
#	install ftp(s) server
#	install ARK server
#	configs
#		upstart file for ARK server
#		iptables - SSH ports, ftp ports, httpd ports, and ark ports
#
###############################################################################




# Maybe we should get this from the user interactively, or at least allow it to
# be specified on the command line.
WEBADMIN="admin"
WEBPASS="admin"


WEBPASSHASH=`echo "$WEBPASS" | md5sum | cut -d" " -f1`


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
touch /tmp/shells.ARKonBoard
sudo cat /etc/shells | grep -v "/usr/sbin/nologin" > /tmp/shells.ARKonBoard
sudo echo "/usr/sbin/nologin" >> /tmp/shells.ARKonBoard
sudo mv /etc/shells /etc/shells.bak
sudo mv /tmp/shells.ARKonBoard /etc/shells
sudo useradd -m steam -s /usr/sbin/nologin
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Modify file limits, etc
#    http://ark.gamepedia.com/Dedicated_Server_Setup
#------------------------------------------------------------------------------
#  1. Modify /etc/sysctl.conf:
touch /tmp/sysctl.conf.ARKonBoard
sudo cat /etc/sysctl.conf | grep -v "fs.file-max=100000" > /tmp/sysctl.conf.ARKonBoard
sudo echo "fs.file-max=100000" >> /tmp/sysctl.conf.ARKonBoard
sudo mv /etc/sysctl.conf /etc/sysctl.conf.bak
sudo mv /tmp/sysctl.conf.ARKonBoard /etc/sysctl.conf

#  2. Apply the change:
sudo sysctl -p /etc/sysctl.conf

#  3. Modify /etc/security/limits.conf:
touch /tmp/security-limits.conf.ARKonBoard
sudo cat /etc/security/limits.conf | grep -v "`cat /etc/security/limits.conf | tail -n1`" | grep -v "*               soft    nofile          1000000" | grep -v "*               hard    nofile          1000000" > /tmp/security-limits.conf.ARKonBoard
sudo echo "*               soft    nofile          1000000" >> /tmp/security-limits.conf.ARKonBoard
sudo echo "*               hard    nofile          1000000" >> /tmp/security-limits.conf.ARKonBoard
sudo echo "# End of file" >> /tmp/security-limits.conf.ARKonBoard
sudo mv /etc/security/limits.conf /etc/security/limits.conf.bak
sudo mv /tmp/security-limits.conf.ARKonBoard /etc/security/limits.conf

#  4. Modify /etc/pam.d/common-session:
touch /tmp/pam.d-common-session.ARKonBoard
sudo cat /etc/pam.d/common-session | grep -v "session required pam_limits.so" > /tmp/pam.d-common-session.ARKonBoard
sudo echo "session required pam_limits.so" >> /tmp/pam.d-common-session.ARKonBoard
sudo cp /etc/pam.d/common-session /etc/pam.d/common-session.bak
sudo mv /tmp/pam.d-common-session.ARKonBoard /etc/pam.d/common-session
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
# Configure lighttpd to use SSL on port 443.
#------------------------------------------------------------------------------
if [ -z "$(cat /etc/lighttpd/lighttpd.conf | grep ':443')" ]; then
	# Create Self-Signed SSL Certificate for web server
	sudo mkdir /etc/lighttpd/certs -p
	sudo openssl req -new -x509 -keyout /etc/lighttpd/certs/lighttpd.pem -out /etc/lighttpd/certs/lighttpd.pem -days 10000 -nodes -subj "/C=US/ST=HTTP Server/L=arkontrol/O=arkontrol-web/OU=arkontrol-php/CN=ssl.arkontrol.com"
	sudo chown www-data:www-data /etc/lighttpd/certs -R
	sudo chmod 0600 /etc/lighttpd/certs

	# Configure lighttpd to use it
	sudo echo '$SERVER["socket"] == ":443" {' >> /etc/lighttpd/lighttpd.conf
	sudo echo '  ssl.engine = "enable"' >> /etc/lighttpd/lighttpd.conf
	sudo echo '  ssl.pemfile = "/etc/lighttpd/certs/lighttpd.pem"' >> /etc/lighttpd/lighttpd.conf
	sudo echo '}' >> /etc/lighttpd/lighttpd.conf
	sudo service lighttpd restart
fi
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Allow webserver to manipulate services 
#------------------------------------------------------------------------------
#TODO: find a configuration that is more restrictive than ALL. `man sudo`
touch /tmp/etc-sudoers.ARKonBoard
sudo cat /etc/sudoers | grep -v "www-data ALL=(ALL) NOPASSWD: ALL" > /tmp/etc-sudoers.ARKonBoard
sudo echo "www-data ALL=(ALL) NOPASSWD: ALL" >> /tmp/etc-sudoers.ARKonBoard
sudo cp /etc/sudoers /etc/sudoers.bak
sudo mv /tmp/etc-sudoers.ARKonBoard /etc/sudoers
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Obtain PHP sources
#------------------------------------------------------------------------------
cd /var/www
#   TODO: move this to fetch from github.com
sudo wget http://cdn.arkontrol.com/arkontrol-php.tar
sudo tar -xvzf arkontrol-php.tar --overwrite
sudo rm -f arkontrol-php.tar
#	TODO: Maybe we can get away with something like 750 instead of 777
sudo chmod 777 /var/www/includes/smarty/templates_c/

# Modify the arkontrol.ini to include our admin info.
touch /tmp/etc-arkontrol.ini.ARKonBoard
sudo cat /etc/arkontrol.ini | sed 's/^webadminname.*/webadminname="${WEBADMIN}"/' | sed 's/^webadminpass.*/webadminpass="${WEBPASSHASH}"/' > /tmp/etc-arkontrol.ini.ARKonBoard
sudo cp /etc/arkontrol.ini /etc/arkontrol.ini.bak
sudo mv /tmp/etc-arkontrol.ini.ARKonBoard /etc/arkontrol.ini
sudo mv /var/www/arkontrol.ini /etc/arkontrol.ini
#	TODO: c'mon, man. chown that and go 660
sudo chmod 777 /etc/arkontrol.ini

sudo chown -R www-data:www-data /var/www
sudo curl --silent 127.0.0.1 > /dev/null
#------------------------------------------------------------------------------



###############################################################################
# install/config FTP server
#http://www.krizna.com/ubuntu/setup-ftp-server-on-ubuntu-14-04-vsftpd/
#   virtual user setup:
#http://www.ubuntugeek.com/configuring-ftp-server-vsftpd-using-text-file-for-virtual-users.html
###############################################################################
sudo apt-get install vsftpd db5.3-util -y

# Self Signed Certificate for FTPS
sudo openssl req -x509 -nodes -days 10000 -newkey rsa:1024 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem -subj "/C=US/ST=FTP Server/L=arkontrol/O=arkontrol/OU=arkontrol-ftp/CN=ssl.arkontrol.com"
sudo mkdir /etc/vsftpd
sudo touch /etc/vsftpd/virtual-users.txt
sudo db5.3_load -T -t hash -f /etc/vsftpd/virtual-users.txt /etc/vsftpd/virtual-users.db
sudo echo "auth required pam_userdb.so db=/etc/vsftpd/virtual-users" > /etc/pam.d/vsftpd.virtual
sudo echo "account required pam_userdb.so db=/etc/vsftpd/virtual-users" >> /etc/pam.d/vsftpd.virtual
sudo chown www-data:www-data /etc/vsftpd/virtual-users.txt
sudo chmod 777 /etc/vsftpd/virtual-users.txt

touch /tmp/vsftpd.conf.tmp.ARKonBoard
sudo cat /etc/vsftpd.conf > /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "anonymous_enable=NO" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "local_enable=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "guest_enable=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "guest_username=steam" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "virtual_use_local_privs=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "write_enable=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "pam_service_name=vsftpd.virtual" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "local_root=/home/steam" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "local_umask=022" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "chroot_local_user=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "allow_writeable_chroot=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "pasv_enable=Yes" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "pasv_min_port=30000" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "pasv_max_port=50000" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "rsa_cert_file=/etc/ssl/private/vsftpd.pem" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "rsa_private_key_file=/etc/ssl/private/vsftpd.pem" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "ssl_enable=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "allow_anon_ssl=NO" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "force_local_data_ssl=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "force_local_logins_ssl=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "ssl_tlsv1=YES" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "ssl_sslv2=NO" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo echo "ssl_sslv3=NO" >> /tmp/vsftpd.conf.tmp.ARKonBoard
sudo mv /etc/vsftpd.conf /etc/vsftpd.conf.bak
sudo mv /tmp/vsftpd.conf.tmp.ARKonBoard /etc/vsftpd.conf

sudo service vsftpd restart
###############################################################################


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
sudo echo "    chown -R steam:steam /home/steam" >> /tmp/ark-dedicated.conf
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
sudo iptables -I INPUT -p tcp --dport 22 -j ACCEPT

# FTP ports
sudo iptables -I INPUT -p tcp --dport 20 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 21 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 30000:50000 -j ACCEPT

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

# ARK rCon port
sudo iptables -I INPUT -p udp --dport 32330 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 32330 -j ACCEPT

# We don't send email. ever.
sudo iptables -A OUTPUT -p tcp --dport 25 -j DROP
sudo iptables -A OUTPUT -p tcp --dport 26 -j DROP
sudo iptables -A OUTPUT -p tcp --dport 143 -j DROP
sudo iptables -A OUTPUT -p tcp --dport 465 -j DROP
sudo iptables -A OUTPUT -p tcp --dport 587 -j DROP
sudo iptables -A OUTPUT -p tcp --dport 993 -j DROP
#------------------------------------------------------------------------------
# make sure all the ports are still open after a reboot
#------------------------------------------------------------------------------
sudo service iptables restart


###############################################################################
# Start the ARK server!!
/home/steam/ark_ds/ShooterGame/Binaries/Linux/ShooterGameServer TheIsland?listen -server -log &
sleep 15
killall -9 ShooterGameServer
sleep 5
sudo mv ~/Steam /home/steam/Steam
if [ ! -d /home/steam/Steam/logs ]; then
	mkdir /home/steam/Steam/logs
fi
sudo chown -R steam:steam /home/steam
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




###############################################################################
# Planned improvements:
###############################################################################
#	FTP server
#	SSH port change / SSH Keys
#	better iptables hardening - CSF+LFD maybe. 
#	test with systemd script on Ubuntu 15.04
#	test with systemd script on CentOS/RHEL/fedora (versions that use systemd)
#	auth info as optional arguments ( -u admin -p password )
###############################################################################
