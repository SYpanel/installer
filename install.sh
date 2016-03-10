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

# Check for debian
OS_NAME=$(lsb_release -si)

if [ ${OS_NAME,,} != 'debian' ]; then
 echo "SYpanel currently works on Debian only!";
 exit;
fi
echo "Upgrading packages"

apt-get upgrade -qq -y --force-yes

echo "Installing necessary packages"

apt-get install wget sudo sed git unzip curl --force-yes -qq -y

CODENAME=$(grep "VERSION=" /etc/os-release |awk -F= {' print $2'}|sed s/\"//g |sed s/[0-9]//g | sed s/\)$//g |sed s/\(//g)

# Install nginx
echo "deb http://nginx.org/packages/debian/ $CODENAME nginx" > /etc/apt/sources.list.d/nginx.list
echo "deb-src http://nginx.org/packages/debian/ $CODENAME nginx" >> /etc/apt/sources.list.d/nginx.list
wget -qO - http://nginx.org/keys/nginx_signing.key | apt-key add -
apt-get update -qq -y --force-yes 
apt-get install -qq -y nginx nginx-extras

# Install MySQL
_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
echo mysql-server mysql-server/root_password password $_PASSWORD | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $_PASSWORD | sudo debconf-set-selections
echo "MySQL root password is $_PASSWORD"
echo $_PASSWORD > ~/.my.cnf
apt-get install --force-yes -y -qq mariadb-server-10.0
apt-get install --force-yes -y -qq bind9

# Clearing
unset _PASSWORD
unset DEBIAN_FRONTEND

# Finally install PHP

apt-get install --force-yes -y -qq php5-fpm php5-cli php5-gd php5-curl php5-json php5-mcrypt

# Fix cgi.fix_pathinfo
sed -i -- 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini

apt-get remove --purge --force-yes -y -qq exim4

apt-get install --force-yes -y -qq postfix 
apt-get install --force-yes -y -qq dovecot-core dovecot-imapd dovecot-mysql dovecot-pop3d #dovecot-antispam

# Setup skel
mkdir /etc/skel/public_html
mkdir /etc/skel/tmp
mkdir /etc/skel/ssl
mkdir /etc/skel/log
cd /etc/skel
ln -s public_html/ www
cd ~

# Create SYpanel user
_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
useradd -d /home/sypanel -m -s /bin/bash -p $_PASSWORD sypanel
unset _PASSWORD

# Allow SYpanel user to sudo without password
printf "\n\n#SYpanel user\nsypanel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Download SYpanel GUI
##TOFIX
cd /home/sypanel/public_html
rm -rf *
git clone https://github.com/SYpanel/SYpanel.git .
cd ~

# Create fpm pool for sypanel
##TODO

# Remove default nginx server
rm -rf /etc/nginx/conf.d/default.conf
service nginx reload

# Create nginx conf for sypanel
read -d '' NGINX_CONF << EOF
server {
    listen 8096 default_server;

    root /home/sypanel/public_html/public;
    index index.php index.html index.htm;

    server_name localhost;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files $uri /index.php =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

echo "$NGINX_CONF" > /etc/nginx/conf.d/sypanel.conf

service nginx reload
