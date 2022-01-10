#!/bin/bash

pacman -Sy dialog --noconfirm

timedatectl set-ntp true

dialog --defaultno --title "Are you sure?" --yesno \
"Don't say YES if you are not sure about what you're doing! \n\n\
Are you sure?" 15 60 || exit

dialog --no-cancel --inputbox "Enter computer name." \
    10 60 2> comp

comp=$(cat comp) && rm comp

uefi=0
ls /sys/firmware/efi/efivars 2> /dev/null && uefi=1

devices_list=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' \
    | grep -E 'sd|hd|vd|nvme|mmcblk'))

dialog --title "Choose hard drive" --no-cancel --radiolist \
"Select with SPACE, continue with ENTER. \n\n" \
15 60 4 "${devices_list[@]}" 2> hd

hd=$(cat hd)

default_size="8"
dialog --no-cancel --inputbox \
"You need four partitions: Boot, Root and Swap \n\
The boot partition will be 512M \n\
The root partition will be the remaining of the hard disk \n\n\
Enter below the partition size (in Gb) for the Swap. \n\n\
If you don't enter anything, it will default to ${default_size}G. \n" \
20 60 2> swap_size

size=$(cat swap_size)

[[ $size =~ ^[0-9]+$ ]] || size=$default_size

dialog --no-cancel \
--title "!!! DELETE EVERYTHING !!!" \
--menu "Choose how to wipe hard disk ($hd)" \
15 60 4 \
1 "Use dd (wipe all disk)" \
2 "Use schred (slow & secure)" \
3 "No need - hard disk is empty" 2> eraser

hderaser=$(cat eraser);

function eraseDisk() {
    case $1 in
        1) dd if=/dev/zero of="$hd" status=progress 2>&1 \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        2) shred -v "$hd" \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        3) ;;
    esac
}

eraseDisk "$hderaser"

boot_partition_type=1
[[ "$uefi" == 0 ]] && boot_partition_type=4

#g - create non empty GPT partition table
#n - create new partition
#p - primary partition
#e - extended partition
#w - write the table to disk and exit

partprobe "$hd"

fdisk "$hd" << EOF
g
n


+512M
t
$boot_partition_type
n


+${size}G
n



w
EOF

partprobe "$hd"

mkswap "${hd}2"
swapon "${hd}2"
mkfs.ext4 "${hd}3"
mount "${hd}3" /mnt

if [ "$uefi" = 1 ]; then
    mkfs.fat -F32 "${hd}1"
    mkdir -p /mnt/boot/efi
    mount "${hd}1" /mnt/boot/efi
fi

pacstrap /mnt base base-devel linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

echo "$uefi" > /mnt/var_uefi
echo "$hd" > /mnt/var_hd
echo "$comp" > /mnt/comp

curl https://raw.githubusercontent.com/cl4irv0yant\
/install/master/install_chroot.sh > /mnt/install_chroot.sh

arch-chroot /mnt bash install_chroot.sh

rm /mnt/var_uefi
rm /mnt/var_hd
rm /mnt/install_chroot.sh
rm /mnt/comp

dialog --title "To reboot or not to reboot?" --yesno \
"Reboot computer?" 20 60

response=$?

case $response in
    0) reboot;;
    1) clear;;
esac
