#!/bin/bash
##############################################
#	SYpanel instellation script				 #
##############################################

# Ignore the post install questions
export DEBIAN_FRONTEND=noninteractive

# SYpanel installer
SY_VERSION="0.0.10"

echo "SYpanel $SY_VERSION";

# Check if we have apt-get
command -v apt-get >/dev/null 2>&1 || { echo "I require apt-get but it's not installed.  Aborting." >&2; exit 1; }

echo "Updating reposetories"

apt-get update -y --force-yes

apt-get install lsb-release -y --force-yes

# Check for debian
OS_NAME=$(lsb_release -si)

if [ ${OS_NAME,,} != 'debian' ]; then
 echo "SYpanel currently works on Debian only!";
 exit;
fi
echo "Upgrading packages"

apt-get upgrade -y --force-yes

echo "Installing necessary packages"

apt-get install wget whois sudo sed git unzip curl --force-yes -y

CODENAME=$(grep "VERSION=" /etc/os-release |awk -F= {' print $2'}|sed s/\"//g |sed s/[0-9]//g | sed s/\)$//g |sed s/\(//g)

# Install nginx
echo "deb http://nginx.org/packages/debian/ $CODENAME nginx" > /etc/apt/sources.list.d/nginx.list
echo "deb-src http://nginx.org/packages/debian/ $CODENAME nginx" >> /etc/apt/sources.list.d/nginx.list
wget -qO - http://nginx.org/keys/nginx_signing.key | apt-key add -
apt-get update -y --force-yes 
apt-get install -y nginx nginx-extras

# Install MySQL
_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
sudo debconf-set-selections <<< "mariadb-server-10.0 mysql-server/root_password password $_PASSWORD"
sudo debconf-set-selections <<< "mariadb-server-10.0 mysql-server/root_password_again password $_PASSWORD"

echo "MySQL root password is $_PASSWORD the password is in ~/.mysql_pass"
echo $_PASSWORD > ~/.mysql_pass
apt-get install --force-yes -y mariadb-server-10.0
apt-get install --force-yes -y bind9

# Create sypanel mysql user and db
_PASSWORD_DB=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
mysql -uroot -p"$_PASSWORD" -e "CREATE DATABASE sypanel;GRANT ALL PRIVILEGES ON sypanel.* TO sypanel@localhost IDENTIFIED BY '$_PASSWORD_DB'";

# Clearing
unset _PASSWORD
unset DEBIAN_FRONTEND

# Finally install PHP
apt-get install --force-yes -y php5-fpm php5-cli php5-gd php5-curl php5-json php5-mcrypt php5-mysql

# Fix cgi.fix_pathinfo
sed -i -- 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini

# Remove Exim
apt-get remove --purge --force-yes -y exim4

# Install postfix and dovecot
debconf-set-selections <<< "postfix postfix/mailname string sypanel"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No configuration'"

apt-get install --force-yes -y postfix 
apt-get install --force-yes -y dovecot-core dovecot-imapd dovecot-mysql dovecot-pop3d #dovecot-antispam

# Setup skel
mkdir /etc/skel/public_html
mkdir /etc/skel/tmp
mkdir /etc/skel/ssl
mkdir /etc/skel/log
cd /etc/skel
ln -s public_html/ www
echo "<?php" > /etc/skel/public_html/index.php;
echo "echo 'Your SYpanel account has been setup.';" >> /etc/skel/public_html/index.php
cd ~

# Create SYpanel user
_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
_PASSWORD_ENC=$(mkpasswd -m sha-512 $_PASSWORD)
useradd -d /opt/sypanel -m -s /bin/bash -p $_PASSWORD_ENC sypanel

# Allow SYpanel user to sudo without password
printf "\n\n#SYpanel user\nsypanel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Download SYpanel GUI

# Install SYM
mkdir /opt/sypanel/public_html/SYM
cd /opt/sypanel/public_html/SYM
rm -rf *
git clone https://github.com/SYpanel/SYM.git .

wget --no-check-certificate -q "https://raw.githubusercontent.com/SYpanel/installer/$SY_VERSION/.env" -O /opt/sypanel/public_html/SYM/.env
sed -i -- "s/DB_PASSWORD=secret/DB_PASSWORD=$_PASSWORD_DB/g" .env

chown -R sypanel:sypanel /opt/sypanel
find /opt/sypanel/public_html -type d -exec chmod 0755 {} \;
find /opt/sypanel/public_html -type f -exec chmod 0644 {} \;

php artisan key:generate
php artisan migrate
cd ~

# Install SYpanel
mkdir /opt/sypanel/public_html/SYpanel
cd /opt/sypanel/public_html/SYpanel
rm -rf *
git clone https://github.com/SYpanel/SYpanel.git .
cp /opt/sypanel/public_html/SYM/.env /opt/sypanel/public_html/SYpanel/.env

unset _PASSWORD_DB
cd ~

chown -R sypanel:sypanel /opt/sypanel
find /opt/sypanel/public_html -type d -exec chmod 0755 {} \;
find /opt/sypanel/public_html -type f -exec chmod 0644 {} \;

# Remove default pool
mv /etc/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/www.bak

# Fetch fpm pool for sypanel
wget --no-check-certificate "https://raw.githubusercontent.com/SYpanel/installer/$SY_VERSION/sypanel.conf" -O /etc/php5/fpm/pool.d/sypanel.conf

service php5-fpm reload

# Remove default nginx server
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.bak

# Fetch nginx conf for sypanel
wget --no-check-certificate "https://raw.githubusercontent.com/SYpanel/installer/$SY_VERSION/nginx.conf" -O /etc/nginx/conf.d/sypanel.conf

service nginx reload

# Done
IP_ADDR=$(ifconfig  | grep 'inet addr:' | grep -v '127.0.0.1' | awk -F: '{print $2}' | awk '{print $1}' | head -1)
echo "SYpanel was installed successfuly"
echo "You can access it at http://$IP_ADDR:8096"
echo "Username: sypanel Password: $_PASSWORD";

unset _PASSWORD