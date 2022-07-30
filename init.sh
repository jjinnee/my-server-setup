#!/bin/bash

#----------------------
# text color
#----------------------
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BG_RED="\e[1;41m"
BG_GREEN="\e[1;42m"
NC="\e[0m"

#----------------------
# check os
#----------------------
if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
fi

if [ "$OS" != "Ubuntu" ]; then
        echo "This script seems to be running on an unsupported distribution."
        echo "Supported distribution is Ubuntu."
        exit
fi

#----------------------
# functions
#----------------------
printError() {
    echo -e "\n${RED}ERROR : $1 ${NC}\n"
    exit
}
printWarn() {
    echo -e "\n${YELLOW}Warn : $1 ${NC}\n"
}
printSuccess() {
    echo -e "\n${GREEN}$1${NC}\n"
}


#--------------------
# update & upgrade
#--------------------
aptUpdate() {
	sudo apt update -y
	sudo DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y
}

echo
echo -e "${BG_GREEN} Updating & Upgrading... ${NC}"

aptUpdate || printError "Failed to upadte"

printSuccess "All updates are installed"

echo
echo -e "${BG_GREEN} Checking... ${NC}"

aptUpdate || printError "Failed to upadte"

printSuccess "All updates are installed"

#----------------------
# install text editor
#----------------------
echo
echo -e "${BG_GREEN} Installing text editor... ${NC}"
sudo apt install nano -y || printError "Failed to install nano"

printSuccess "nano is installed"

echo
echo -e "${BG_GREEN} Setting nano configs... ${NC}"
cat << EOF | sudo tee -a /etc/nanorc

set softwrap
set tabsize 4
EOF

#----------------------
# install logrotate
#----------------------
echo
echo -e "${BG_GREEN} Installing logrotate... ${NC}"
sudo apt install logrotate -y || printError "Failed to install logrotate"

printSuccess "logrotate is installed"

#----------------------
# install net-tools
#----------------------
echo
echo -e "${BG_GREEN} Installing net-tools... ${NC}"
sudo apt install net-tools -y || printError "Failed to install net-tools"

printSuccess "net-tools is installed"

#----------------------
# initialize firewall
#----------------------
echo
echo -e "${BG_GREEN} Installing firewall... ${NC}"
sudo apt install iptables -y || printError "Failed to install iptables"

printSuccess "iptables is installed"

# echo

# mkdir -p data || echo -e "${YELLOW}Warn : '$HOME/data' is already exists.${NC}\n"
# cat << EOF | tee $HOME/data/iptables.sh && echo -e "iptables restore script is located in ${GREEN}$HOME/data/iptables.sh${NC}\n"
# #!/bin/bash
# IPT="sudo iptables"

# #\$IPT -N WEB
# #\$IPT -A WEB -p tcp -m multiport --dport 80,443 -j ACCEPT
# #\$IPT -A WEB -p tcp --dport 80 -j ACCEPT
# #\$IPT -A WEB -p tcp --dport 443 -j ACCEPT
# #\$IPT -A WEB -j RETURN

# #\$IPT -I INPUT 1 -j WEB
# EOF

# chmod +x $HOME/data/iptables.sh

#-------------------
# install crontab
#-------------------
echo
echo -e "${BG_GREEN} Installing crontab... ${NC}"
sudo apt install cron -y || printError "Failed to install cron"

printSuccess "cron is installed"

### user cron
cat << EOF | crontab || printError "Can't create default cron jobs : $USER"
# m h dom mon dow command
@reboot sudo iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
EOF

printSuccess "Default cron jobs are created : $USER"

### root cron
cat << EOF | sudo crontab || printError "Can't create default cron jobs : root"
# m h dom mon dow command
0 5 * * * sudo reboot
EOF

printSuccess "Default cron jobs are created : root"

#-------------------------
# change timezone
#-------------------------
#sudo ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
sudo timedatectl set-timezone Asia/Seoul

#-------------------------
# get docker install file
#-------------------------
echo
echo -e "${BG_GREEN} Downloading docker install script... ${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh || printError "Failed to get docker install script"

printSuccess "docker install script is located in $HOME/get-docker.sh"

#-------------------------
# reset password
#-------------------------
echo
echo -e "${BG_GREEN} Password reset ${NC}"
sudo passwd -d "$USER" || printError "Failed to reset password : $USER"

printSuccess "Reseted password for user : $USER"

#------------------------
# alias
#------------------------
echo
echo -e "${BG_GREEN} Adding alias... ${NC}"

cat << EOF | tee -a $HOME/.bashrc

alias update='sudo apt list --upgradable && echo "------------------------------------" && sudo apt update && sudo apt dist-upgrade -y'
alias mv='mv -v'
alias rm='rm -v'
alias cp='cp -v'

alias d='sudo docker'

alias s='sudo'

alias ipt='sudo iptables'
alias ipt6='sudo ip6tables'

alias nlog='cat /var/log/nginx/access.log'
alias nelog='cat /var/log/nginx/error.log'
EOF

source $HOME/.bashrc

#------------------------
# create opt program
#------------------------
echo
echo -e "${BG_GREEN} saving opt program... ${NC}"

SAVED_PATH="/usr/local/bin/opt"

cat << EOF | sudo tee $SAVED_PATH && sudo chmod +x $SAVED_PATH
#!/bin/bash

GREEN="\e[1;32m"
BG_GREEN="\e[1;42m"
NC="\e[0m"

echo -e "\${BG_GREEN} journalctl --vacuum-time=1d \${NC}"
sudo journalctl --vacuum-time=1d

echo
echo -e "\${BG_GREEN} Delete unused apps \${NC}"
sudo apt autoremove -y

echo
echo -e "\${BG_GREEN} Delete APT cache \${NC}"
sudo apt-get clean

echo
echo -e "\${BG_GREEN} Delete unused kernel files \${NC}"
sudo apt autoremove --purge

echo
echo -e "\${BG_GREEN} /var/log/**/*.gz \${NC}"
sudo find /var/log -name '*.gz' -exec rm {} \;

echo
echo -e "\${BG_GREEN} /var/log/**/*.[0-9] \${NC}"
sudo find /var/log -name '*.[0-9]' -exec rm {} \;
echo
echo -e "\${BG_GREEN} /var/log/**/*.[0-9][0-9] \${NC}"
sudo find /var/log -name '*.[0-9][0-9]' -exec rm {} \;
echo
echo -e "\${BG_GREEN} /var/log/**/*.[0-9][0-9][0-9] \${NC}"
sudo find /var/log -name '*.[0-9][0-9][0-9]' -exec rm {} \;
echo
EOF

#------------------------
# reboot
#------------------------
echo
echo -e "${BG_RED} TO DO AFTER REBOOT ${NC}"
echo -e "1. Password reset"
echo -e "\t${GREEN}$ passwd${NC}"
echo -e "2. select editor"
echo -e "\t${GREEN}$ select-editor${NC}"
echo -e "\t${GREEN}$ sudo select-editor${NC}"
echo -e "3. Install docker"
echo -e "\t${GREEN}$ sudo sh get-docker.sh${NC}"

echo
echo -e "${BG_GREEN} ADDED THINGS ${NC}"
echo -e "- Added cron jobs : ${GREEN}Reboot${NC}"
echo -e "- Added shortcuts"
echo -e "\t${GREEN}$ update${NC} : sudo apt update && sudo apt dist-upgrade -y"
echo -e "\t${GREEN}$ d${NC} : sudo docker"
echo -e "\t${GREEN}$ ipt${NC} : sudo iptables"
echo -e "\t${GREEN}$ ipt6${NC} : sudo ip6tables"
echo -e "\t${GREEN}$ lxd${NC} : sudo lxd"
echo -e "\t${GREEN}$ lxc${NC} : sudo lxc"
echo -e "\t${GREEN}$ nlog${NC} : cat /var/log/nginx/access.log"
echo -e "\t${GREEN}$ nelog${NC} : cat /var/log/nginx/error.log"

echo
echo -e "${BG_GREEN} NEW COMMAND ${NC}"
echo -e "- clean up unused files"
echo -e "\t${GREEN}$ opt${NC}"
echo -e "- Auto package update"
echo -e "\t${GREEN}$ update${NC}"

echo

sudo reboot
