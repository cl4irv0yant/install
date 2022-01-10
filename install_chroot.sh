#!/bin/bash

uefi=$(cat /var_uefi); hd=$(cat /var_hd);

cat /comp > /etc/hostname && rm /comp

pacman --noconfirm -S dialog

pacman -S --noconfirm grub

if [ "$uefi" = 1 ]; then
    pacman -S --noconfirm efibootmgr
    grub-install --target=x86_64-efi \
        --bootloader-id=GRUB \
        --efi-directory=/boot/efi
else
    grub-install "$hd"
fi

grub-mkconfig -o /boot/grub/grub.cfg

hwclock --systohc
timedatectl set-timezone Europe/Stockholm

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

loadkeys sv-latin1
echo "KEYMAP=sv-latin1" >> /etc/vconsole.conf

function config_user() {
    if [ -z "$1" ]; then
        dialog --no-cancel --inputbox "Enter username." \
            10 60 2> name
    else
        echo "$1" > name
    fi
    dialog --no-cancel --passwordbox "Enter password." \
        10 60 2> pass1
    dialog --no-cancel --passwordbox "Confirm password." \
        10 60 2> pass2
    while [ "$(cat pass1)" != "$(cat pass2)" ]
    do
        dialog --no-cancel --passwordbox \
            "Passwords do not match.\n\nEnter password again." \
            10 60 2> pass1
        dialog --no-cancel --passwordbox \
            "Confirm password." \
            10 60 2> pass2
    done

    name=$(cat name) && rm name
    pass1=$(cat pass1) && rm pass1 pass2

    # Create user if doesn't exist
    if [[ ! "$(id -u "$name" 2> /dev/null)" ]]; then
        dialog --infobox "Adding user $name..." 4 50
        useradd -m -g wheel -s /bin/bash "$name"
    fi

    # Add password to user
    echo "$name:$pass1" | chpasswd
}

dialog --title "root password" \
    --msgbox "Enter root password." \
    10 60
config_user root

dialog --title "Add User" \
    --msgbox "Let's create another user." \
    10 60
config_user

echo "$name" > /tmp/user_name

dialog --title "Continue installation" --yesno \
"Continue to install applications and dotfiles." \
10 60 \
&& curl https://raw.githubusercontent.com/cl4irv0yant\
/install/master/install_apps.sh > /tmp/install_apps.sh \
&& bash /tmp/install_apps.sh
