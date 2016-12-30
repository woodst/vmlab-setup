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
    echo " fullSetupset up the entire VMLab from nothing"
    echo 
    echo " Discrete functions (run by the macro functions above):"
    echo " --------------------------------------------------------------------------------------------------------"
    echo " mountInstallDirectorycreate a local directory with a remote mount to the log directory"
    echo " logWrite to the log file.  See documentation for usage."
    echo ""
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