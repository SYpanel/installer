#!/bin/bash

# Ignore the post install questions
export DEBIAN_FRONTEND=noninteractive

# SYpanel installer
SY_VERSION="0.0.1" 

echo "SYpanel $SY_VERSION";

command -v apt-get >/dev/null 2>&1 || { echo "I require apt-get but it's not installed.  Aborting." >&2; exit 1; }

echo "Updating reposetories"

apt-get update -qq -y --force-yes

apt-get install lsb-release -qq -y --force-yes

# check for debian
OS_NAME=$(lsb_release -si)

if [ ${OS_NAME,,} != 'debian' ]; then
 echo "SYpanel currently works on Debian only!";
 exit;
fi
echo "Upgrading packages"

apt-get upgrade -qq -y --force-yes

echo "Installing necessary packages"

apt-get install wget sed git unzip curl --force-yes -qq -y

CODENAME=$(grep "VERSION=" /etc/os-release |awk -F= {' print $2'}|sed s/\"//g |sed s/[0-9]//g | sed s/\)$//g |sed s/\(//g)

# install nginx
echo "deb http://nginx.org/packages/debian/ $CODENAME nginx" > /etc/apt/sources.list.d/nginx.list
echo "deb-src http://nginx.org/packages/debian/ $CODENAME nginx" >> /etc/apt/sources.list.d/nginx.list
wget -qO - http://nginx.org/keys/nginx_signing.key | apt-key add -
apt-get update -qq -y --force-yes 
apt-get install -qq -y nginx nginx-extras

#install MySQL
_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
echo mysql-server mysql-server/root_password password $_PASSWORD | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $_PASSWORD | sudo debconf-set-selections
echo "MySQL root password is $_PASSWORD"
echo $_PASSWORD > ~/.my.cnf
apt-get install --force-yes -y -qq mariadb-server-10.0
apt-get install --force-yes -y -qq bind9

#clearing
unset _PASSWORD
unset DEBIAN_FRONTEND

#finally install PHP

apt-get install --force-yes -y -qq php5-fpm php5-cli php5-gd php5-curl php5-json php5-mcrypt

# fix cgi.fix_pathinfo
sed -i -- 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini

apt-get remove --purge --force-yes -y -qq exim4

apt-get install --force-yes -y -qq postfix 
apt-get install --force-yes -y -qq dovecot-core dovecot-imapd dovecot-mysql dovecot-pop3d #dovecot-antispam

#install SYpanel
mkdir /usr/share/sypanel && cd /usr/share/sypanel

wget https://github.com/SYpanel/SYpanel/archive/master.zip
unzip master.zip

cd ~

# setup skel
mkdir /etc/skel/public_html
mkdir /etc/skel/tmp
mkdir /etc/skel/ssl
mkdir /etc/skel/log
cd /etc/skel
ln -s public_html/ www
cd ~