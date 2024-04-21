#!/usr/bin/env bash

# This script should check how old is the TAI-UTC file heliocentric_correction/tai-utc.dat
# and update it from http://maia.usno.navy.mil/ser7/tai-utc.dat if needed

NEED_TO_UPDATE_THE_FILE=0


# Get current date from the system clock
CURRENT_DATE_UNIXSEC=`date +%s`

# check if the file is there at all
if [ ! -f heliocentric_correction/tai-utc.dat ];then
 echo "ERROR opening file heliocentric_correction/tai-utc.dat" >> /dev/stderr
 NEED_TO_UPDATE_THE_FILE=1
else
 # First try Linux-style stat
 TAImUTC_DAT_FILE_MODIFICATION_DATE=`stat -c "%Y" heliocentric_correction/tai-utc.dat 2>/dev/null`
 if [ $? -ne 0 ];then
  TAImUTC_DAT_FILE_MODIFICATION_DATE=`stat -f "%m" heliocentric_correction/tai-utc.dat 2>/dev/null`
  if [ $? -ne 0 ];then
   echo "ERROR cannot get modification time for heliocentric_correction/tai-utc.dat" >> /dev/stderr
   exit 1
  fi
 fi
fi

# 15778454 is about 6 months
# 7889227 is about 3 months
if [ $[$CURRENT_DATE_UNIXSEC-$TAImUTC_DAT_FILE_MODIFICATION_DATE] -gt 7889227 ];then
 NEED_TO_UPDATE_THE_FILE=1
fi

# Update the file if needed
if [ $NEED_TO_UPDATE_THE_FILE -eq 1 ];then
 wget --timeout=120 --tries=3 -O tai-utc.dat.new "http://maia.usno.navy.mil/ser7/tai-utc.dat"
 if [ $? -ne 0 ];then
  echo "ERROR running wget" >> /dev/stderr
  if [ -f tai-utc.dat.new ];then
   rm -f tai-utc.dat.new
  fi
  wget --timeout=120 --tries=3 -O tai-utc.dat.new "ftp://toshi.nofs.navy.mil/ser7/tai-utc.dat"
  if [ $? -ne 0 ];then
   echo "ERROR2 running wget" >> /dev/stderr
   if [ -f tai-utc.dat.new ];then
    rm -f tai-utc.dat.new
   fi
   wget --timeout=120 --tries=3 -O tai-utc.dat.new "ftp://cddis.gsfc.nasa.gov/pub/products/iers/tai-utc.dat"
   if [ $? -ne 0 ];then
    echo "ERROR2 running wget" >> /dev/stderr
    exit 1
   fi
  fi
 fi
 if [ ! -s tai-utc.dat.new ];then
  echo "ERROR: tai-utc.dat.new is EMPTY!"  >> /dev/stderr
  exit 1
 fi
 mv -v tai-utc.dat.new heliocentric_correction/tai-utc.dat && touch heliocentric_correction/tai-utc.dat
fi
