#!/bin/bash
# Bootstrap Install Script For Cactive™️ Managed VPS'

# Ensure we are running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Update system apt list
echo "Updating apt list"
apt update -y

# Upgrade existing packages
echo "Upgrading existing packages"
apt upgrade -y

# Install required packages
echo "Installing required packages via apt"
apt install build-essential git gnupg python3 imagemagick nginx certbot python3-certbot-nginx neofetch figlet zsh -y

# Perform basic system configuration
echo "Performing basic system configuration"

# Request name of server
echo "What is the name of this server? (Amazon naming scheme)"
read -p "Server Name: " servername

# Request connections token
echo "What is the connections token for this server?"
read -p "Connections Token: " connectionstoken

# Request github username
echo "Github credentials to associate with this machine"
read -p "Username: " githubuser
read -p "Token: " githubtoken

git config --global user.name "$servername"
git config --global user.email "$servername@cactive.network"
git config --global credential.helper store
echo "https://$githubuser:$githubtoken@github.com" > ~/.git-credentials

# Set hostname
hostnamectl set-hostname $servername

# Set timezone
timedatectl set-timezone Australia/Melbourne

# Remove /etc/motd if it exists
if [ -f /etc/motd ]; then
    rm /etc/motd
    # Todo: Remove pam motd
fi

# Configure motd
mkdir /opt/meta
touch /opt/meta/ssh_motd
curl -s http://www.figlet.org/fonts/ogre.flf > /usr/share/figlet/ogre.flf
echo "\n-----------------------------------------------------------------------------\n" > /opt/meta/ssh_motd
figlet -f ogre $servername >> /opt/meta/ssh_motd
echo "\n-----------------------------------------------------------------------------\n" >> /opt/meta/ssh_motd
echo "This service is provided by Cactive.\n" >> /opt/meta/ssh_motd
echo "All actions performed on this machine are monitored, and misuse will be penalized.\n\n" >> /opt/meta/ssh_motd
sed -i 's/#Banner/Banner \/opt\/meta\/ssh_motd #/' /etc/ssh/sshd_config
sed -i 's/#PrintMotd/PrintMotd yes #/' /etc/ssh/sshd_config

# Install Node.js
echo "Installing Node.js"
curl -fsSL https://deb.nodesource.com/setup_19.x | bash - &&\
apt-get install -y nodejs

# Install Node.js packages
echo "Installing Node.js packages"
npm install -g pm2 && pm2 setup
npm install -g typescript
npm i

# Configure auth
echo "Configuring auth"
git clone https://github.com/CactiveNetwork/auth/ /opt/auth
cd /opt/auth
npm i -D && tsc -p . && npm link
cat "\nLOGIN_TOKEN=$connectionstoken\nVPS_NAME=$servername\n$SOCKET_LOCATION=wss://auth.cactive.network" > .env
cat "\nauth   required    pam_exec.so stdout log=/var/log/auth.log /opt/auth/auth" > /etc/pam.d/sshd

# Start rich bootstrap
node ./rich.js $githubtoken

# Restart processes
echo "Restarting processes"
systemctl restart sshd