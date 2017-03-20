#!/bin/bash

# ======================================================
# setup.sh
# version 1.0.0
# ------------------------------------------------------
#
# vmlab setup script
# featured in the text "Build Your Own Virtualization 
# Lab"
#
# ------------------------------------------------------
# Copyright 2016, Thomas M. Woods
# 
# This script is distributed under the terms of the 
# GNU Affero General Public License v3.0
#
# ======================================================


# ======================================================
# Script Configuration Data
# ------------------------------------------------------
# F-010
# ======================================================

# Installation and logging information
loglocation="woodst@10.10.100.100:vmlab/install/"
localdirectory="install/"
logfilename="setuplog.log.txt"
mountlist="mountList.txt"
mirrorlist="mirrorList.txt"

# keymappath provides a full path and file name
keymappath="/usr/share/kbd/keymaps/i386/qwerty/us.map.gz"

# Keymap is the name of the key mapping file 
keymap="us.map.gz"

# timezone
timezone="UTC"

# Partition List is the drive by drive partition specification
# filename.  It shoulbd be placed in the remote install
# directiory, and must be there before it can be called.
# See the documentation for schema
partspec="partspec.txt"

# Flatten Phrase - must be typed as the second parameter when calling 
# the flatten function
flattenPhrase="antiquing"

# Networking and Host Name
hostName="vmlab01.home.woodsnet.org"

presNetName="wn-presentation"
presNetMAC="fc:aa:14:de:f7:68"
presNetIP="10.10.40.10/24"
presNetGW="10.10.40.254"

appNetName="wn-application"
appNetMAC="fc:aa:14:de:f7:69"
appNetIP="10.10.50.10/24"
appNetGW="10.10.50.254"

dataNetName="wn-data"
dataNetMAC="fc:aa:14:de:f7:6a"
dataNetIP="10.10.60.10/24"
dataNetGW="10.10.60.254"

manageNetName="wn-manage"
manageNetMAC="fc:aa:14:de:f7:6b"
manageNetIP="10.10.70.10/24"
manageNetGW="10.10.70.254"

# Root Password
rootPass=Kepler01

# Boot Loader path
bootfilepath="/mnt/boot/loader/entries"

# Boot Loader filename
bootfile="arch.conf"

# ======================================================
# mountInstallDirectory
# ------------------------------------------------------
# F-020
# ------------------------------------------------------
# Create $localDirectory and mount it with the remote
# $loglocation.  
# ======================================================
mountInstallDirectory() {

    if [ -e $localdirectory ] 
    then
        echo " Enter a password for the remote log directory:"
	sshfs $loglocation $localdirectory
    else
        mkdir $localdirectory
        echo " Enter a password for the remote log directory:"
	sshfs $loglocation $localdirectory
    fi

}

# =======================================================
# log
# -------------------------------------------------------
# F-020
# -------------------------------------------------------
# Start a log file if one doesn't exist on the remote
# directory and write the action to it.
# Also capture the output in a discrete file numbered
# for the setup in the macro function caller. 
# =======================================================
log() {
    if test -w "$localdirectory$logfilename"
    then
	date >> "$localdirectory$1.log.txt"
        echo "-----------------------------------" >> "$localdirectory$1.log.txt"
	eval $2 | tee --append "$localdirectory$1.log.txt" 
        echo "$1, $2, $3, $(date), $?" | tee --append $localdirectory$logfilename
        echo "[$1] $2" 
echo "-----------------------------------" >> "$localdirectory$1.log.txt"
date >> "$localdirectory$1.log.txt"
    else
eval $2 
        tempOut=$?
echo "ID ,Function ,Description ,DateTime ,Result" >> $localdirectory$logfilename
        echo "$1, $2, $3, $(date), $tempOut" | tee --append $localdirectory$logfilename 
        echo "[$1] $2"
    fi
}


# =======================================================
# setUpKeyboard
# -------------------------------------------------------
# F-030
# -------------------------------------------------------
# Load the keyboard mapping file:
# Verify the mapping file exists, is readable and then 
# apply it to the current setup.
# -------------------------------------------------------
setupKeyboard() {

if [[ $(type loadkeys) != "" && $(type localectl) != "" ]]
then
    echo "keymap file exists at $keymappath ... setting keymap" 
    loadkeys $keymap
    localectl set-keymap --no-convert $keymap
else
    echo "[setup.sh] something went wrong with keyboard mapping."
    return 1;
fi

}


# =======================================================
# setupTime
# -------------------------------------------------------
# F-040
# -------------------------------------------------------
# Set the Date and Time:
# We want NTP to govern the the actual date and time, 
# but we need to tell it which timezone we want.
# ###################################################
setupTime() {

if [[ $(type timedatectl) != "" ]] 
then
    timedatectl set-timezone $timezone
    timedatectl set-ntp true
    timedatectl status
else
    echo "[setup.sh] something went wrong with timedatectl"
fi

}



# =======================================================
# clean
# -------------------------------------------------------
# F-050
# -------------------------------------------------------
# Archive log files into a date/time-labeled directory,
# unmount and remove the install directory and any 
# other files, with the exception of this script.
# =======================================================
clean () {
    if [[ -e "$localdirectory" ]]
    then
        echo "Cleaning up...\n"

        # organize any previous installation files
        backupDir=$(date "+install.%y.%m.%d.%H.%M.%s")
        mkdir $localdirectory/$backupDir
        mv $localdirectory/*.log.txt $localdirectory/$backupDir

        # unmount and remove the install directory
        umount $localdirectory
        rmdir $localdirectory

	# if there is a $mountlist file in the local directory,
	# remove that too.
	if test -w "$mountlist"
	then
	    rm -f "$mountlist"
	fi
	
    else
        echo "Nothing to clean."
    fi

}

# =========================================================
# DiskMap
# ---------------------------------------------------------
# F-060
# ---------------------------------------------------------
# Helper function that generates a data file of all
# onboard disks and places diskmap.txt on the remote
# installation drive.  See the documentation for file
# format information.  DiskMap will mount the remote 
# drive if it doesn't already exist.
# =========================================================
diskMap() {
if [ -e "$localdirectory" ]
then
    if [[ $(type lsblk) != "" ]]
    then
        mapfile="drivelist.txt"
        lsblk -b --output "NAME,HOTPLUG,MODEL,SERIAL,SIZE,WWN,HCTL,MAJ:MIN,TRAN,REV" >> "$localdirectory$mapfile"
    else
        echo "lsblk is not installed"
    fi
else
    mountInstallDirectory
    diskMap
fi
}

# =======================================================
# partSetup
# -------------------------------------------------------
# F-070
# -------------------------------------------------------
# loads the partition specifcation file (see script
# data) and sets up partitions on each physical disk
# per the spcification.
# =======================================================
partSetup() {
    if [[ $(type sgdisk) != "" ]] && test -e "$localdirectory$partspec"
	echo $localdirectory$partspec
    then
	while read -r drive 
	do
	    echo "*********************************************************************************"
	    echo "PartSetup: "${drive}
	    echo "*********************************************************************************"
	    echo " "
            ${drive}
	done < "$localdirectory$partspec"
    else
	echo "Something went wrong with partSetup"
	return 1
    fi
}

# =======================================================
# dismountAll
# -------------------------------------------------------
# F-080.1
# -------------------------------------------------------
# Unmount the basic vmlab file systems.  Note that these should be any mounts
# that occur under the /mnt directory. The temporary file $mountlist is used
# but is writted locally instead of to the installation directory in order to
# make the function usable without having to mount the installation directory.
# =======================================================
dismountAll() {
    echo "Unmounting file systems..."
    # Make a list of mountings under the /mnt directory
    findmnt -l -o "TARGET" | grep /mnt/ > "$mountlist"

    #Read the mount list and dismount everything
    while read -r part
    do
	umount -f ${part}
    done < "$mountlist"
}

# =======================================================
# removePartitions
# -------------------------------------------------------
# F-080.2
# -------------------------------------------------------
# Prerequisite: Volumes are not mounted.
# -------------------------------------------------------
# Flatten the system by restoring all drives to a 
# zero partitioned state.  Use with caution!
# =======================================================
removePartitions() {
    #
    for sdsk in $(lsblk --noheadings --output="PKNAME")
    do        
        sgdisk -z /dev/$sdsk
    done 
}


# =======================================================
# removeMultidisks
# -------------------------------------------------------
# F-080.3
# -------------------------------------------------------
# Prerequisite: Volumes are not mounted.
# -------------------------------------------------------
# Tear down the multidisk volume, overwrite the various
# superblocks and Zap the partitions.
# =======================================================
removeMultidisks() {
    for mdsk in $(lsblk --output="KNAME" | grep "md" | uniq)
    do
	members=$(mdadm --detail /dev/$mdsk | grep -oh "/dev/sd[a-z]")
        echo "Removing /dev/$mdsk..."
        mdadm --remove /dev/$mdsk
        mdadm --stop /dev/$mdsk

        for member in $members
        do
            echo "wiping $member"
            mdadm --zero-superblock $member
            sgdisk -Z $member
        done   
    done
}

# =======================================================
# Nuclear
# -------------------------------------------------------
# F-080.4
# -------------------------------------------------------
# Flatten the system by restoring all drives to a 
# zero partitioned state.  Use with caution!
# =======================================================
nuclear() {

if [[ $(type sgdisk) != "" ]] && test "$1" = "$flattenPhrase"
then
    echo "kaboom!"

    # Unmount everything in /mnt
    unmountAll
    
    # clear any Multi-Disk devices
    removeMultidisks
    
    # Clear the physical drives
    removePartitions
    
    # Run the clean() function
    clean

else
    echo "You didn't use the command correctly!"
fi

}

# =======================================================
# basePackageInstall
# -------------------------------------------------------
# F-090
# -------------------------------------------------------
# Prerequisit: All drives partitioned and mounted
# -------------------------------------------------------
# Performs an installation of the base Arch Linux
# system
# =======================================================
basePackageInstall() {
    echo "Installing the base Arch Linux packages... "

    # rename the existing mirror file and fetch the one from
    # setup that has only local mirrors
    if test -e "Slocaldirectory$mirrorList"
    then
	cp /etc/pacman.d/mirrors /etc/pacman.d/mirrorlist.old
    else
	echo "there is no mirror in /etc/pacman.d"
    fi

    if test -e "$localdirectory$mirrorList"
    then
	cp "$localdirectory$mirrorList" /etc/pacman.d/mirrorlist
    else
	echo "there is no mirror file in the install directory"
    fi 
    
    # base install
    pacstrap /mnt base

    # Install extra packages needed into the new root
    # EFI firmware variable access
    echo "Installing efivar... "
    arch-chroot /mnt su root -c "pacman -S efivar --noconfirm"

    # Intel Microcode update (TODO - set up boot partition to use this!)
    echo "Installing Intel microcode updates... "
    arch-chroot /mnt su root -c "pacman -S intel-ucode --noconfirm"

}


# =======================================================
# configSystem
# -------------------------------------------------------
# F-100
# -------------------------------------------------------
# Prerequisite: /mnt mountings and basePackageInstall
# -------------------------------------------------------
# Configure the new system
# Configure several settings on the new system rooted 
# at /mnt
# =======================================================
configSystem() {
    # start with generation of fstab by label
    genfstab -L /mnt >> /mnt/etc/fstab

    # set the host name
    echo $hostName > /mnt/etc/hostname
    echo "127.0.0.1        $hostName.localdomain $hostName" >> /mnt/etc/hosts
    echo "Host name is $hostName"

    # set time parameter /etc/adjtime for the new root
    # hwclock does not run as an indirect chroot.
    hwclock --systohc --utc
    cp /etc/adjtime /mnt/etc/adjtime

    # set the locale
    # start with a working backup of the initial file, then
    # uncomment the locale needed. Do this for every locale 
    # desired.  Run locale-gen as the new system root.
    cp /mnt/etc/locale.gen /mnt/etc/locale.gen.backup
    sed "s/#en_US.UTF-8/en_US.UTF-8/g" /mnt/etc/locale.gen.backup > /mnt/etc/locale.gen

    arch-chroot /mnt su - root -c "locale-gen"

    # and record the choice made
    echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf

}


# =======================================================
# configNetwork
# -------------------------------------------------------
# F-110
# -------------------------------------------------------
# Prerequisite: /mnt mountings and basePackageInstall
# -------------------------------------------------------
# Configure the new network interfaces on /mnt
# =======================================================
configNetwork() {
# write the network config files to be used by systemd
echo 'SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="'$presNetMAC'", NAME="'$presNetName'"' >> /mnt/etc/udev/rules.d/10-network.rules
echo 'SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="'$appNetMAC'", NAME="'$appNetName'"' >> /mnt/etc/udev/rules.d/10-network.rules
echo 'SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="'$dataNetMAC'", NAME="'$dataNetName'"' >> /mnt/etc/udev/rules.d/10-network.rules
echo 'SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="'$manageNetMAC'", NAME="'$manageNetName'"' >> /mnt/etc/udev/rules.d/10-network.rules

# Write the config file for wn-presentation
echo '[Match]' >> /mnt/etc/systemd/network/$presNetName.network
echo 'Name='"$presNetName" >> /mnt/etc/systemd/network/$presNetName.network
echo ' ' >> /mnt/etc/systemd/network/$presNetName.network
echo '[Network]' >> /mnt/etc/systemd/network/$presNetName.network
echo 'Address='"$presNetIP" >> /mnt/etc/systemd/network/$presNetName.network
echo ' ' >> /mnt/etc/systemd/network/$presNetName.network
echo '[Route]' >> /mnt/etc/systemd/network/$presNetName.network
echo 'Gateway='"$presNetGW" >> /mnt/etc/systemd/network/$presNetName.network

# Write the config file for wn-application
echo '[Match]' >> /mnt/etc/systemd/network/$appNetName.network
echo 'Name='"$appNetName" >> /mnt/etc/systemd/network/$appNetName.network
echo ' ' >> /mnt/etc/systemd/network/$appNetName.network
echo '[Network]' >> /mnt/etc/systemd/network/$appNetName.network
echo 'Address='"$appNetIP" >> /mnt/etc/systemd/network/$appNetName.network
echo ' ' >> /mnt/etc/systemd/network/$appNetName.network
echo '[Route]' >> /mnt/etc/systemd/network/$appNetName.network
echo 'Gateway='"$appNetGW" >> /mnt/etc/systemd/network/$appNetName.network

# Write the config file for wn-data
echo '[Match]' >> /mnt/etc/systemd/network/$dataNetName.network
echo 'Name='"$dataNetName" >> /mnt/etc/systemd/network/$dataNetName.network
echo ' ' >> /mnt/etc/systemd/network/$dataNetName.network
echo '[Network]' >> /mnt/etc/systemd/network/$dataNetName.network
echo 'Address='"$dataNetIP" >> /mnt/etc/systemd/network/$dataNetName.network
echo ' ' >> /mnt/etc/systemd/network/$dataNetName.network
echo '[Route]' >> /mnt/etc/systemd/network/$dataNetName.network
echo 'Gateway='"$dataNetGW" >> /mnt/etc/systemd/network/$dataNetName.network

# Write the config file for wn-management
echo '[Match]' >> /mnt/etc/systemd/network/$manageNetName.network
echo 'Name='"$manageNetName" >> /mnt/etc/systemd/network/$manageNetName.network
echo ' ' >> /mnt/etc/systemd/network/$manageNetName.network
echo '[Network]' >> /mnt/etc/systemd/network/$manageNetName.network
echo 'Address='"$manageNetIP" >> /mnt/etc/systemd/network/$manageNetName.network
echo ' ' >> /mnt/etc/systemd/network/$manageNetName.network
echo '[Route]' >> /mnt/etc/systemd/network/$manageNetName.network
echo 'Gateway='"$manageNetGW" >> /mnt/etc/systemd/network/$manageNetName.network

# Write the Google name servers to resolve.conf
echo 'nameserver 8.8.8.8' >> /mnt/etc/resolv.conf
echo 'nameserver 8.8.8.4' >> /mnt/etc/resolv.conf

# Ensure the network is active on reboot
arch-chroot /mnt su - root -c "systemctl enable systemd-networkd"
arch-chroot /mnt su - root -c "systemctl enable systemd-resolved"

}

# =======================================================
# initRAM
# -------------------------------------------------------
# F-120
# -------------------------------------------------------
# Initialize the RAM image for the kernel, and install it
# in the /mnt root.
# =======================================================
initRAM() {

arch-chroot /mnt su - root -c "mkinitcpio -p linux"

}

# =======================================================
# setPass
# -------------------------------------------------------
# F-130
# -------------------------------------------------------
# Set the root password at /mnt
# =======================================================
setPass() {

arch-chroot /mnt su - root -c "echo root:$rootPass | chpasswd"

}


# =======================================================
# configBoot
# -------------------------------------------------------
# F-140
# -------------------------------------------------------
# Set up the boot loader, UEFI and systemd at /mnt
# =======================================================
configBoot() {

    # add read only mounting of efivars to the new system 
    # fstab, and then make sure it is mounted under chroot
    echo 
    echo "efivarfs    /sys/firmware/efi/efivars  efivarfs  ro, nosuid, nodev, noexec, noatime 0 0" >> /mnt/etc/fstab
    arch-chroot /mnt su - root -c "mount -t efivarfs efivarfs /sys/firmware/efi/efivars"

    # Install bootctl
    arch-chroot /mnt su - root -c "bootctl install"

    # Install Intel microcode 
    # (TODO: Investigate conflict with base install)
    #arch-chroot /mnt su - root -c "pacman -S intel-ucode"

    # Get the PARTUID of the root partion
    rootpart=$(blkid -L root)
    partuuid=$(blkid -s PARTUUID -o value $rootpart)

    # Write the arch.conf boot loader config file
    mkdir -p $bootfilepath
    echo "title Arch Linux" >> $bootfilepath/$bootfile
    echo "linux /vmlinuz-linux" >> $bootfilepath/$bootfile
    # echo "initrd /intel-ucode.img" >> $bootfilepath/$bootfile
    echo "initrd /initramfs-linux.img" >> $bootfilepath/$bootfile
    echo "options root=PARTUUID=$partuuid rw" >> $bootfilepath/$bootfile

    # Screen refresh
    clear
}


# =======================================================
# configShell
# -------------------------------------------------------
# F-150
# -------------------------------------------------------
# Set up the Z shell at /mnt
# =======================================================
configShell() {

    # Use the FISH shell
    arch-chroot /mnt su - root -c "pacman -S fish --noconfirm"
    arch-chroot /mnt su - root -c "chsh -s /usr/bin/fish"

    # Set up and enable secure shell for remote login
    # Note that we will be working as root for a while
    # until the OpenStack install is complete, so only
    # root is enabled here.

    # Refresh the openSSH install
    arch-chroot /mnt su - root -c "pacman -S openssh --noconfirm"

    # Permit root
    echo "AllowUsers root" >> /mnt/etc/ssh/sshd_config
    echo "PermitRootLogin yes" >> /mnt/etc/ssh/sshd_config

    # set the service
    arch-chroot /mnt su - root -c "systemctl enable sshd"

}


# =======================================================
# cleanReboot
# -------------------------------------------------------
# F-160
# -------------------------------------------------------
# Mop up installation artifacts, eject the DVD, reboot.
# =======================================================
cleanReboot() {
    # Clean up the installation files
    echo "Cleaning up..."
    clean

    # Reboot the system
    clear
    echo "Installation complete - removing the installation media and rebooting... "
    umount -l /dev/sr0
    eject /dev/sr0
    reboot --poweroff
}


# =======================================================
# installSupplemental
# -------------------------------------------------------
# F-170
# -------------------------------------------------------
# Install supplemental packages, see the individual
# comments for each.
# =======================================================
installSupplemental() {

    # Install git
    echo "Installing git..."
    arch-chroot /mnt su - root -c "pacman -S git --noconfirm"

    # Install emacs
    echo "installing emacs..."
    arch-chroot /mnt su - root -c "pacman -S emacs --noconfirm"

    # Install gpt fdisk utilities to get sgdisk
    echo "installing gptfdisk..."
    arch-chroot /mnt su - root -c "pacman -S gptfdisk --noconfirm"

    # Install python
    echo "installing python..."
    arch-chroot /mnt su - root -c "pacman -S python --noconfirm"

    # Install django
    echo "installing django..."
    arch-chroot /mnt su - root -c "pacman -S python-django --noconfirm"

    # install lsb-release
    echo "installing lsb-release..."
    arch-chroot /mnt su - root -c "pacman -S lsb-release --noconfirm"

    # install sudo
    echo "installing sudo..."
    arch-chroot /mnt su - root -c "pacman -S sudo --noconfirm"
    
}



# =======================================================
# returnCatalog
# -------------------------------------------------------
# F-020
# -------------------------------------------------------
# list out the functions in this script - called 
# whenever a requested function doesn't exist.
# =======================================================
returnCatalog() {
    echo
    echo " The setup script has the following functions:"
    echo
    echo " Macro Functions:"
    echo " --------------------------------------------------------------------------------------------------------"
    echo " fullSetup                      set up the entire VMLab from nothing"
    echo 
    echo " Discrete functions (run by the macro functions above):"
    echo " --------------------------------------------------------------------------------------------------------"
    echo " clean                          archive artifacts and unmount/remove the remote installation directory."
    echo " mountInstallDirectory          create a local directory with a remote mount to the log directory."
    echo " log                            Write to the log file.  See documentation for usage."
    echo " setupKeyboard                  Set up the local keyboard used during installation."
    echo " setupTime                      Set System Time, Timezone, use of NTP."
    echo " partSetup                      Set up partions according to $partspec and its child scripts."
    echo " dismountAll                    Dismount every partition under /mnt."
    echo " removePartitions               Remove every partition."
    echo " removeMultidisks               Remove any Multi-Disk Confirurations."
    echo " basePackageInstall             Install the Arch Linux base packages."
    echo " installSupplemental            Install additional needed packages to /mnt"
    echo " configSystem                   Configure the newly installed base system at /mnt"
    echo " configNetwork                  Configure the networking for the newly installed base system at /mnt"
    echo " initRAM                        Initialize the RAM-based kernel in the new root at /mnt"
    echo " setPass                        Set the root password at /mnt"
    echo " configBoot                     Configure the Boot Loader, UEFI, systemd at /mnt"
    echo " configShell                    Configure the Z shell at /mnt"
    echo " cleanReboot                    Clean up installation files, eject the DVD, reboot."
    echo
    echo " Helper Functions:"
    echo " --------------------------------------------------------------------------------------------------------"
    echo " nuclear                        Flatten the installation and return it to an unconfigured state."
    echo " diskmap                        creates a text file dump of all physical drives on this system"
    echo 
}


# ========================================================
# Full Setup 
# --------------------------------------------------------
# F-020 (introduced on HF-010)
# --------------------------------------------------------
# Performs a complete setup of the VMLab, from nothing
# Use clean before running this script.
# ========================================================
fullSetup() {
    
    # 0010 Start by making an installation directory and mounting the remote directory
    log 0010 mountInstallDirectory "Installation Directory Mounted "

    # 0020 Set the system time (F-030)
    log 0020 setupKeyboard "Keyboard mapping set "

    # 0030 Set the system time
    log 0030 setupTime "System time set "

    # 0040 Configure Drives and Partitions
    log 0040 partSetup "Drives are being configured "

    # 0050 Install base packages
    log 0050 basePackageInstall "Base Arch Linux Pachages are being installed"

    # 0055 Install supplemental packages
    log 0055 installSupplemental "Supplemental Arch Linux Pachages are being installed"

    # 0060 Configure System
    log 0060 configSystem "Configure the new system installed at /mnt"

    # 0070 Configure Network
    log 0070 configNetwork "Configure networking for the new system installed at /mnt"

    # 0080 Initialize RAM image
    log 0080 initRAM "Intializing Kernel RAM image at /mnt"

    # 0090 Set the root password for the new system
    log 0090 setPass "Setting the root password "

    # 0100 Set up the boot loader
    log 0100 configBoot "Setting up the boot environment "

    # 0110 Set up the Z shell
    log 0110 configShell "Configuring the interactive Z shell "

    # 9999 Set up the Z shell
    log 9999 cleanReboot "Cleaning up installation and rebootiing "

}


# ======================================================
# Main
# ------------------------------------------------------
# F-020
# ------------------------------------------------------
# Always run the passed in function, or in the absence
# of a valid function return a list of all the
# functions in the script.
# ======================================================
if [[ $(type $1) != "" ]]
then
    $1 $2
else
    returnCatalog
fi
