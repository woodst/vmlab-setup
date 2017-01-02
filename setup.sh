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

# keymappath provides a full path and file name
keymappath="/usr/share/kbd/keymaps/i386/qwerty/us.map.gz"

# Keymap is the name of the key mapping file 
keymap="us.map.gz"

# timezone
timezone="UTC"



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
    echo " clean                          archive artifacts and unmount/remove the remote installation directory"
    echo " mountInstallDirectory          create a local directory with a remote mount to the log directory"
    echo " log                            Write to the log file.  See documentation for usage."
    echo " setupKeyboard                  Set up the local keyboard used during installation"
    echo " setupTime                      Set System Time, Timezone, use of NTP"
    echo 
    echo " Helper Functions:"
    echo " --------------------------------------------------------------------------------------------------------"
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