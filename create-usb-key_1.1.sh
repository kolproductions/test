#!/bin/bash

#
# this file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# this file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# For more details, write to the Free Software Foundation, 
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. 
#
# Author: Gianluca Moro <giangiammy@gmail.com>
# Date: 2010-03-10
# Version 1.0_beta2
# Copyright (C) 2010 Gianluca Moro

# All sizes are MegaBytes                                                                                 
USBMINTOTALSIZE=1999
USBMINOSSIZE=1500
USBMINDATASIZE=200

function do_exit {
  /etc/init.d/hal start
  exit 0
}

function abort {
  zenity --title "Bye" --info --text "Installation aborted.\nInstallazione annullata\n\nBye"
  do_exit
}

function debug {
    echo -n "Debug: "
    echo $1
}

debug "Starting ..."

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   #echo "This script must be run as root. Bye."
   gksu $0
   exit 1
fi

if [ x$(which unetbootin) == x ] ; then 
   zenity --title "Bye" --info --text "To create CloudUSB you need to install\nPer creare CloudUSB devi installare\nunetbootin\n\nBye";
   abort;
fi

zenity --title "WARNING/ATTENZIONE" --question --text "This procedure will create the CloudUSB key\nWARNING: You will lose ALL the data on the drive where you put CloudUSB!\n\nQuesta procedura crea una chiave CloudUSB\nATTENZIONE: Perderai tutti i dati presenti nel drive in cui installi CloudUSB!\n\nYou must have already downloaded the ISO image from:\nDevi aver gia' scaricato l'immagine ISO da:\n\nhttp://cloudusb.net/\n\nContinue? / Continuare?"

if [ $? = 1 ] ; then
    abort;
fi

debug "Looking for disks ..."

DISKINFO=$(fdisk -l | grep "Disk /dev/" )

declare -a arr

arr=( `echo "$DISKINFO" | awk '{ print $2 }' | tr ':\n' '  ' ` )

#(echo "List of disks:" ; echo "Lista dei dischi:" ; echo ; echo "$DISKINFO") | zenity --text-info --width 530 --height 300

nelem=${#arr[@]}
lastn=$((nelem-1))

debug "Selecting installation disk ..."

declare -a arrtf
for ii in $(seq 0 $((${#arr[@]} - 1)))
do
    it=$((ii*2))
    iv=$((it+1))
    arrtf[$it]="FALSE"
    arrtf[$iv]="${arr[$ii]}"
done

arrtf[$it]="TRUE"

#echo ${arrtf[@]}

SELECTEDDISK=`zenity --title "Disk selection/Selezione disco" --list --height 300  --text "Where do you want to install CloudUSB?\nDove vuoi installare CloudUSB?" --radiolist  --column "Select" --column "Disk" ${arrtf[@]}`

if [ $? = 1 ] ; then
    abort;
fi

VERBOSEDISKINFO=$(fdisk -l $SELECTEDDISK)

zenity --title "WARNING/ATTENZIONE" --question --width 530 --height 300 --text "You are installing CloudUSB on the following disk.\nALL DATA WILL BE LOST!\nContinue?\n\nStai Installando CloudUSB sul seguente disco.\nTUTTI I DATI VERRANNO PERSI.\nContinuo?\n\n$VERBOSEDISKINFO"

if [ $? = 1 ] ; then
    abort;
fi

zenity --title "WARNING/ATTENZIONE" --question --width 530 --height 300 --text "Last Warning: Deleting data on $SELECTEDDISK\n\nUltimo avvertimento: cancello i dati presenti su $SELECTEDDISK"

if [ $? = 1 ] ; then
    abort;
fi

debug "Partitioning ..."

/etc/init.d/hal stop

debug "Umounting and removing partitions ..."
umount ${SELECTEDDISK}1 2>/dev/null
parted $SELECTEDDISK rm 1 >/dev/null
umount ${SELECTEDDISK}2 2>/dev/null
parted $SELECTEDDISK rm 2 >/dev/null
umount ${SELECTEDDISK}3 2>/dev/null
parted $SELECTEDDISK rm 3 >/dev/null
umount ${SELECTEDDISK}4 2>/dev/null
parted $SELECTEDDISK rm 4 >/dev/null

debug "Getting USB key size in MB ..."
USBTOTALSIZE=$(parted $SELECTEDDISK unit MB print devices | grep $SELECTEDDISK | awk '{ print $2}' | tr "()MB" " ")
USBTOTALSIZE=$((USBTOTALSIZE-1)) 

debug "USB key size in MB is: ${USBTOTALSIZE}"
USBOSSIZE=$((USBTOTALSIZE/2)) 

if [ $USBTOTALSIZE -lt $USBMINTOTALSIZE ] ; then
  zenity --info --text "USB key must be at least 2Gb\nLa chiave USB deve essere da almeno 2Gb\n\nInstallation aborted.\nInstallazione annullata\n\nBye"
  do_exit
fi

if [ $USBOSSIZE -lt $USBMINOSSIZE ] ; then
    USBOSSIZE=$USBMINOSSIZE
fi

USBDATASIZE=$((USBTOTALSIZE-USBOSSIZE))
USBDATAMAXSIZE=$((USBTOTALSIZE-USBMINOSSIZE))

modified=$(zenity --title "Personalize data size" --scale --text "USB key data partition will be: ${USBDATASIZE}MB\nSpazio riservato ai dati: ${USBDATASIZE}MB\n\nYou can change it if you want.\nPuoi cambiarlo se vuoi." --min-value=$USBMINDATASIZE --max-value=$USBDATAMAXSIZE --value=$USBDATASIZE --step 1);echo $ans

if [ x$modified != "x" ] ; then
    debug "Manage size selection"
    if [ $modified -ne $USBDATASIZE ] ; then
	debug "Modify data size - set to $modified"
	USBDATASIZE=$modified
	USBOSSIZE=$((USBTOTALSIZE-USBDATASIZE))
    fi
fi

debug "Partitioning to ${USBOSSIZE}MB : parted -s $SELECTEDDISK mkpart primary fat32 28.7kB ${USBOSSIZE}MB >/dev/null" 
parted -s $SELECTEDDISK mkpart primary fat32 28.7kB ${USBOSSIZE}MB >/dev/null
USBOSSIZE=$((USBOSSIZE+1)) 

debug "Partitioning from ${USBOSSIZE}MB to ${USBTOTALSIZE} : parted -s $SELECTEDDISK mkpart primary ext2 ${USBOSSIZE}MB ${USBTOTALSIZE}MB" 
parted -s $SELECTEDDISK mkpart primary ext2 ${USBOSSIZE}MB ${USBTOTALSIZE}MB >/dev/null

#Model: Kingston DataTraveler 2.0 (scsi)
#Disk /dev/sdb: 4013MB
#Sector size (logical/physical): 512B/512B
#Partition Table: msdos
#
#Number  Start   End     Size    Type     File system  Flags
# 1      28.7kB  1682MB  1682MB  primary  fat32        boot, lba
# 2      1682MB  4012MB  2329MB  primary  ext2


debug "Formatting partition (1) ..."
umount ${SELECTEDDISK}1 2>/dev/null
mkfs.vfat ${SELECTEDDISK}1 | (zenity --title "Formatting ..." --text "Formatting ${SELECTEDDISK}1 ..." --progress --pulsate --auto-close)

debug "Formatting partition (2) ..."
umount ${SELECTEDDISK}2 2>/dev/null
mkfs.ext2 -b 4096 -L casper-rw ${SELECTEDDISK}2 | (zenity --title "Formatting ..." --text "Formatting ${SELECTEDDISK}2 ..." --progress --pulsate --auto-close)

mkdir -p /media/usbkey
umount ${SELECTEDDISK}1 2>/dev/null
mount ${SELECTEDDISK}1 /media/usbkey
rm -rf /media/usbkey/*

debug "Copying files to USB key ..."
# CLI mode does not work :-)
unetbootin method=diskimage isofile="~/custombackup.iso" message="CloudUSB from http://www.cloudusb.net" autoinstall=yes | (zenity --title "Copying data to USB KEY ..." --text "Select Diskimage ISO and point to the ISO image on your disk\nSelect USB Drive, Drive ${SELECTEDDISK}1\nAnd press OK\nAt the end press 'Exit'" --progress --pulsate --auto-close)

#remastersys clean

debug "Setup boot files ..."

sed -i 's/append initrd=\/ubninit file=\/cdrom\/preseed\/custom.seed boot=casper quiet splash --/append initrd=\/ubninit file=\/cdrom\/preseed\/custom.seed boot=casper persistent quiet splash --/g' /media/usbkey/syslinux.cfg 

sed -i 's/UNetbootin/CloudUSB Boot - http:\/\/www.cloudusb.net/g' /media/usbkey/syslinux.cfg 

sed -i 's/Default/CloudUSB/g' /media/usbkey/syslinux.cfg 

sed -i 's/timeout 100/timeout 50/g' /media/usbkey/syslinux.cfg 

/etc/init.d/hal start

zenity --title "Bye" --info --text "Installation Completed.\nInstallazione completata.\n\nYou can leave feedback at info@cloudusb.net\nPuoi inviare un commento a info@cloudusb.net\n\nBye"

debug "Done."