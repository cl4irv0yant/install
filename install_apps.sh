#!/bin/bash

name=$(cat /tmp/user_name)

apps_path="/tmp/apps.csv"

curl https://raw.githubusercontent.com/cl4irv0yant\
/install/master/apps.csv > $apps_path

apps=("essential" "Essentials" on
      "network" "Network" on
      "tools" "Nice tools to have (highly recommended)" on
      "tmux" "Tmux" on
      "notifier" "Notification tools" on
      "git" "Git & git tools" on
      "i3" "i3 wm" on
      "zsh" "The Z-Shell (zsh)" on
      "neovim" "Neovim" on
      "urxvt" "URxvt" on
      "firefox" "Firefox (browser)" on
      "js" "JavaScript tooling" off
      "qutebrowser" "Qutebrowser (browser)" off
      "lynx" "Lynx (browser)" off)

dialog --checklist \
"Choose which applications to install. \n\n\
Select with SPACE and continue with ENTER." \
0 0 0 \
"${apps[@]}" 2> app_choices
choices=$(cat app_choices) && rm app_choices

selection="^$(echo $choices | sed -e 's/ /,|^/g'),"
lines=$(grep -E "$selection" "$apps_path")
count=$(echo "$lines" | wc -l)
packages=$(echo "$lines" | awk -F, {'print $2'})

echo "$selection" "$lines" "$count" >> "/tmp/packages"

pacman -Syu --noconfirm

rm -f /tmp/aur_queue

dialog --title "Let's go!" --msgbox \
"Installation will take some time!\n\n " \
13 60

c=0
echo "$packages" | while read -r line; do
    c=$(( "$c" + 1 ))

    dialog --title "Installation" --infobox \
    "Downloading and installing program $c out of $count: $line..." \
    8 70

    ((pacman --noconfirm --needed -S "$line" > /tmp/arch_install 2>&1) \
    || echo "$line" >> /tmp/aur_queue) \
    || echo "$line" >> /tmp/arch_install_failed
    if [ "$line" = "zsh" ]; then
        # Set Zsh as default terminal for our user
        chsh -s "$(which zsh)" "$name"
    fi
    if [ "$line" = "networkmanager" ]; then
        systemctl enable NetworkManager.service
    fi
done
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
curl https://raw.githubusercontent.com/cl4irv0yant\
/install/master/install_user.sh > /tmp/install_user.sh;
sudo -u "$name" sh /tmp/install_user.sh
