#!/bin/bash
# 32 MB disk = 64000
DISKSIZE=32
BLOCKSIZE=2000
NUMSECTORS=`expr $DISKSIZE \* $BLOCKSIZE`
mydev=`/usr/bin/hdiutil attach -nomount ram://$NUMSECTORS`
newfs_hfs $mydev
mkdir /Volumes/RAMDisk
diskutil mount -mountpoint /Volumes/RAMDisk/ $mydev