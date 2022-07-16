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
echo -e "\t 2) mount external storage"
echo -e "\t 3) openssl private certificate"
echo
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
        echo -e "Crontab:root${NC}"
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

### 2 - mount external storage

if [[ $answer == 2 ]]; then
    echo
    echo -e "${BG_CYAN} What storage path do you want to mount? ${NC}"
    echo && ls /dev
    echo
    read -p "> Answer [Default: exit] : " storageName

    [ -z $storageName ] && exit

    exist=$(ls /dev | grep $storageName)
    [[ -z $exist ]] && printError "The path you entered does not exist"

    storagePath="/dev/$storageName"

    mounted=$(mount | grep $storagePath)
    if [[ -n $mounted ]]; then
        echo
        echo -e "${BG_GREEN} Do you want to unmount? ${NC}"
        echo -e "You already mount ${RED}$storagePath${NC} to ${RED}$(mount | grep /dev/sdb | awk '{print $3}')${NC}"
        echo
        read -p "> Answer (y/n) [Default: n] : " wantToUmount

        [[ -z $wantToUmount || $wantToUmount != y ]] && wantToUmount=n

        if [[ $wantToUmount == y ]]; then
            sudo umount $storagePath
            sudo crontab -l | grep -v "@reboot sudo mount $storagePath" | sudo crontab -
            echo
            echo -e "${GREEN}Mounted storages${NC}"
            df -h
            echo
            exit
        elif [[ $wantToUmount == n ]]; then
            printError "You already mount $storagePath to $(mount | grep /dev/sdb | awk '{print $3}')"
        fi
    fi

    echo
    echo -e "${BG_CYAN} Where do you want to mount $storagePath? ${NC}"
    echo -e "i.e. ${GREEN}/mount${NC} or ${GREEN}/home/[user]/[dirName]${NC} or ${GREEN}whatever${NC}"
    echo
    read -p "> Answer [Default: exit] : " mountPath

    [[ -z $mountPath ]] && exit

    echo
    sudo mount $storagePath $mountPath || printError "Can't mount $storagePath to $mountPath"

    cat << EOF | sudo crontab
$(sudo crontab -l)
@reboot sudo mount $storagePath
EOF

    echo -e "${GREEN}Mounted storages${NC}"
    df -h
    echo
    echo -e "${GREEN}Result after editing crontab:root${NC}"
    sudo crontab -l
    echo
fi

### 3 - openssl private certificate

if [[ $answer == 3 ]]; then
    echo
    echo -e "${BG_CYAN} What directory name do you want to make? ${NC}"
    read -p "> Answer [Default : exit] : " dirName

    [ -z $dirName ] && exit

    echo
    mkdir $dirName || printError "Can't make directory"

    echo
    cd $dirName
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -out certificate.crt

    echo
    echo -e "${BG_CYAN} Do you want to create dhparam? ${NC}"
    read -p "> Answer (2048/4096) [Default : exit] : " dhparam

    [ -z $dhparam ] && exit

    [[ $dhparam =~ 2048|4096 ]] && echo "$(openssl dhparam $dhparam)" > dhparam.pem
        echo
fi
