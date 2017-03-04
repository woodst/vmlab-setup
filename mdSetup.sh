#! /bin/bash

# ======================================================
# mdSetup.sh
# ------------------------------------------------------
# Configure this file to run mdadm for
# any multi-disk setups used in the 
# vmlab.
# ======================================================
# Usage:
# From the partspec.txt file:  
# chown and chmod mdSetup.sh as needed
# call mdSetup
# cat /proc/mdstat (to be picked up by
#  the logging function)
# write the content of mdadm --detail
#  to the numbered setup log.
# ####################################

echo "Y" |  mdadm --create /dev/md0 --name="coldstore" --level=5 --raid-devices=4 /dev/sd{q,r,s,t} --force
