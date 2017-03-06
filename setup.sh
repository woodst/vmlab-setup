#!/bin/bash

# ======================================================
# setup.sh
# version 0.1.0
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
loglocation="woodst@192.168.1.21:vmlab/install/"
localdirectory="install/"
logfilename="setuplog.log.txt"
mountlist="mountList.txt"

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
    echo 
    echo " Helper Functions:"
    echo " --------------------------------------------------------------------------------------------------------"
    echo " nuclear                        Flatten the installation and return it to an unconfigured state."
    echo " 
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
