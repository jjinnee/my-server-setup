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

# Usage: bannerColor "my title" "red" "*"
function bannerColor() {
    case ${2} in
        black) color=0
        ;;
        red) color=1
        ;;
        green) color=2
        ;;
        yellow) color=3
        ;;
        blue) color=4
        ;;
        magenta) color=5
        ;;
        cyan) color=6
        ;;
        white) color=7
        ;;
        *) echo "color is not set"; exit 1
        ;;
    esac

    local msg="${3} ${1} ${3}"
    local edge
    edge=${msg//?/$3}
    tput setaf ${color}
    tput bold
    echo "${edge}"
    echo "${msg}"
    echo "${edge}"
    tput sgr 0
    echo
}


# Usage: multiChoice "header message" resultArray "comma separated options" "comma separated default values"
# Credit: https://serverfault.com/a/949806
function multiChoice {
    echo "${1}"; shift
    echo "$(tput dim)""- Change Option: [up/down], Change Selection: [space], Done: [ENTER]" "$(tput sgr0)"
    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()   { printf "%s" "${ESC}[?25h"; }
    cursor_blink_off()  { printf "%s" "${ESC}[?25l"; }
    cursor_to()         { printf "%s" "${ESC}[$1;${2:-1}H"; }
    print_inactive()    { printf "%s   %s " "$2" "$1"; }
    print_active()      { printf "%s  ${ESC}[7m $1 ${ESC}[27m" "$2"; }
    get_cursor_row()    { IFS=';' read -rsdR -p $'\E[6n' ROW COL; echo "${ROW#*[}"; }
    key_input()         {
        local key
        IFS= read -rsn1 key 2>/dev/null >&2
        if [[ $key = ""      ]]; then echo enter; fi;
        if [[ $key = $'\x20' ]]; then echo space; fi;
        if [[ $key = $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key = [A ]]; then echo up;    fi;
            if [[ $key = [B ]]; then echo down;  fi;
        fi
    }
    toggle_option()    {
        local arr_name=$1
        eval "local arr=(\"\${${arr_name}[@]}\")"
        local option=$2
        if [[ ${arr[option]} == 1 ]]; then
            arr[option]=0
        else
            arr[option]=1
        fi
        eval "$arr_name"='("${arr[@]}")'
    }

    local retval=$1
    local options
    local defaults

    IFS=';' read -r -a options <<< "$2"
    if [[ -z $3 ]]; then
        defaults=()
    else
        IFS=';' read -r -a defaults <<< "$3"
    fi

    local selected=()

    for ((i=0; i<${#options[@]}; i++)); do
        selected+=("${defaults[i]}")
        printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow
    lastrow=$(get_cursor_row)
    local startrow=$((lastrow - ${#options[@]}))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for option in "${options[@]}"; do
            local prefix="[ ]"
            if [[ ${selected[idx]} == 1 ]]; then
                prefix="[x]"
            fi

            cursor_to $((startrow + idx))
            if [ $idx -eq $active ]; then
                print_active "$option" "$prefix"
            else
                print_inactive "$option" "$prefix"
            fi
            ((idx++))
        done

        # user key control
        case $(key_input) in
            space)  toggle_option selected $active;;
            enter)  break;;
            up)     ((active--));
                if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
            down)   ((active++));
                if [ "$active" -ge ${#options[@]} ]; then active=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to "$lastrow"
    printf "\n"
    cursor_blink_on

    indices=()
    for((i=0;i<${#selected[@]};i++)); do
        if ((selected[i] == 1)); then
            indices+=("${i}")
        fi
    done

    # eval $retval='("${selected[@]}")'
    eval "$retval"='("${indices[@]}")'
}


clear

# Usage: multiChoice "header message" resultArray "comma separated options" "comma separated default values"
multiChoice "Select options:" result "update & upgrade;install nano;install logrotate;install net-tools;No contents;install cron;set timezone to KR;get docker install file;reset password;No contents;create opt" "1;1;1;1;0;1;1;0;0;0;1"

count=0
for item in ${result[@]}; do
    result[count]=$(echo "obase=16; ${item}" | bc)
    ((count++))
done

#--------------------
# update & upgrade
#--------------------
aptUpdate() {
	sudo apt update -y
	sudo DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y
}

if [[ "${result[*]}" =~ 0 ]]; then
    echo
    echo -e "${BG_GREEN} Updating & Upgrading... ${NC}"

    aptUpdate || printError "Failed to upadte"

    printSuccess "All updates are installed"

    echo
    echo -e "${BG_GREEN} Checking... ${NC}"

    aptUpdate || printError "Failed to update"

    printSuccess "All updates are installed"
fi


#----------------------
# install text editor
#----------------------
if [[ "${result[*]}" =~ 1 ]]; then
    echo
    echo -e "${BG_GREEN} Installing text editor... ${NC}"
    sudo DEBIAN_FRONTEND=noninteractive apt install nano -y || printError "Failed to install nano"

    printSuccess "nano is installed"

    echo
    echo -e "${BG_GREEN} Setting nano configs... ${NC}"
    cat << EOF | sudo tee -a /etc/nanorc

set softwrap
set tabsize 4
EOF
fi


#----------------------
# install logrotate
#----------------------
if [[ "${result[*]}" =~ 2 ]]; then
    echo
    echo -e "${BG_GREEN} Installing logrotate... ${NC}"
    sudo DEBIAN_FRONTEND=noninteractive apt install logrotate -y || printError "Failed to install logrotate"

    printSuccess "logrotate is installed"
fi


#----------------------
# install net-tools
#----------------------
if [[ "${result[*]}" =~ 3 ]]; then
    echo
    echo -e "${BG_GREEN} Installing net-tools... ${NC}"
    sudo DEBIAN_FRONTEND=noninteractive apt install net-tools -y || printError "Failed to install net-tools"

    printSuccess "net-tools is installed"
fi


#----------------------
# initialize firewall
#----------------------
if [[ "${result[*]}" =~ 4 ]]; then
    echo "No contents"
    #echo
    #echo -e "${BG_GREEN} Installing firewall... ${NC}"
    #sudo DEBIAN_FRONTEND=noninteractive apt install iptables -y || printError "Failed to install iptables"

    #printSuccess "iptables is installed"
fi


#-------------------
# install crontab
#-------------------
if [[ "${result[*]}" =~ 5 ]]; then
    echo
    echo -e "${BG_GREEN} Installing crontab... ${NC}"
    sudo DEBIAN_FRONTEND=noninteractive  apt install cron -y || printError "Failed to install cron"

    printSuccess "cron is installed"
fi


#-------------------------
# change timezone
#-------------------------
if [[ "${result[*]}" =~ 6 ]]; then
    #sudo ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
    sudo timedatectl set-timezone Asia/Seoul
fi


#-------------------------
# get docker install file
#-------------------------
if [[ "${result[*]}" =~ 7 ]]; then
    echo
    echo -e "${BG_GREEN} Downloading docker install script... ${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh || printError "Failed to get docker install script"

    printSuccess "docker install script is located in $HOME/get-docker.sh"
fi


#-------------------------
# reset password
#-------------------------
if [[ "${result[*]}" =~ 8 ]]; then
    echo
    echo -e "${BG_GREEN} Password reset ${NC}"
    sudo passwd -d "$USER" || printError "Failed to reset password : $USER"

    printSuccess "Reseted password for user : $USER"
fi


#------------------------
# alias
#------------------------
if [[ "${result[*]}" =~ 9 ]]; then
    echo "No contents"
fi

#------------------------
# create opt program
#------------------------
if [[ "${result[*]}" =~ A ]]; then
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
fi


#------------------------
# reboot
#------------------------
bannerColor "TO DO AFTER REBOOT" "red" "*"

if [[ "${result[*]}" =~ 8 ]]; then
    echo -e "Reset password"
    echo -e "\t${GREEN}$ passwd${NC}"
fi
if [[ "${result[*]}" =~ 7 ]]; then
    echo -e "Install docker"
    echo -e "\t${GREEN}$ sudo sh get-docker.sh${NC}"
fi
echo

bannerColor "CHANGED" "yellow" "*"

if [[ "${result[*]}" =~ 4 ]]; then
    echo -e "- Iptables config file is saved on ${GREEN}${HOME}/.iptables${NC}"
    echo
fi

if [[ "${result[*]}" =~ 6 ]]; then
    echo -e "- ${GREEN}Time zone${NC} changed to Asia/Seoul"
    echo
fi

if [[ "${result[*]}" =~ 9 ]]; then
    echo -e "- Added shortcuts"
    echo -e "\t${GREEN}$ mv${NC} : mv -v"
    echo -e "\t${GREEN}$ rm${NC} : rm -v"
    echo -e "\t${GREEN}$ cp${NC} : cp -v"
    echo
    echo -e "\t${GREEN}$ d${NC} : sudo docker"
    echo
    echo -e "\t${GREEN}$ s${NC} : sudo"
    echo -e "\t${GREEN}$ ss${NC} : sudo service"
    echo -e "\t${GREEN}$ sn${NC} : sudo nano"
    echo
    echo -e "\t${GREEN}$ ipt${NC} : sudo iptables"
    echo -e "\t${GREEN}$ ipt6${NC} : sudo ip6tables"
    echo
    echo -e "\t${GREEN}$ nlog${NC} : cat /var/log/nginx/access.log"
    echo -e "\t${GREEN}$ nelog${NC} : cat /var/log/nginx/error.log"
    echo
fi

sudo reboot
