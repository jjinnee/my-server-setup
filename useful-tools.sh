#!/bin/bash

#----------------------
# text color
#----------------------
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BG_RED="\e[1;41m"
BG_GREEN="\e[1;42m"
BG_CYAN="\e[1;46m"
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

#----------------------
# select tool
#----------------------
echo
echo -e "${BG_GREEN} Select number ${NC}"
echo -e "\t 1) swap memory"

read -p "> Answer [Default : exit] : " answer

[ -z $answer ] && exit

#----------------------
# run
#----------------------

### 1 - swap memory
if [[ $answer == 1 ]]; then
        echo
        echo -e "${BG_CYAN} How much swap memory do you need? ${NC}"
        echo -e "${RED}You can type${NC} ${GREEN}off${NC} ${RED}when you want to off swap memory${NC}"
        echo
        free -h
        echo
        read -p "> Answer (GB | off) [Default : exit] : " user_swap

        [ -z $user_swap ] && exit

        if [[ $user_swap =~ [0-9]{1,} ]]; then
                [ $(free -h | sed -n 3p | awk '{print $2}') != 0B ] && printError "You already have swap memory"
                echo
                sudo fallocate -l ${user_swap}GB /swapfile || printError "Failed to create swap memory"

                echo
                sudo chmod 600 /swapfile

                echo
                sudo mkswap /swapfile

                echo
                sudo swapon /swapfile

                echo
                echo -e "${GREEN}Result after creating swap memory${NC}"
                free -h

                echo
                cat << EOF | sudo crontab
$(sudo crontab -l)
@reboot sudo swapon /swapfile
EOF
                echo
                echo -e "${GREEN}Result after editing crontab:root${NC}"
                sudo crontab -l
                echo
                sudo service cron reload
        elif [[ $user_swap == off ]]; then
                [ $(free -h | sed -n 3p | awk '{print $2}') == 0B ] && printError "You don't have not swap memory"
                sudo swapoff /swapfile
                echo
                sudo rm /swapfile
                echo
                echo -e "${GREEN}Result after creating swap memory${NC}"
                free -h
                echo
                sudo crontab -l | grep -v "@reboot sudo swapon /swapfile" | sudo crontab -
                echo
                echo -e "${GREEN}Result after editing crontab:root${NC}"
                sudo crontab -l
                echo
                sudo service cron reload
        fi
fi
