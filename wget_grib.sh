#!/bin/bash

# Script to download GRIB data 

# Copyright 2018 Chris Abela <kristofru@gmail.com> , Malta
# Copyright 2013 Malta Air Traffic Services Ltd., Malta
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Usage : wget_grib.sh [-q]
# -q  For a quiter execution of the script. This means that you will not get
#     any information on the download progress. Errors will always get printed.

get_dates() {
  [ "$1" = quiet ] && U="-nv" || unset U
  # Hint setting U to "-q" will make wget completely silent
  wget $U $URL -O $OUT
  YEAR_MONTH=$( cut -c 31-36 $OUT | sort -n | tail -1 )
  rm $OUT
  wget $U ${URL}/${YEAR_MONTH} -O $OUT
  YEAR_MONTH_DAY=$( cut -c 31-38 $OUT | sort -n | tail -1 )
  rm $OUT
  wget $U ${URL}/${YEAR_MONTH}/${YEAR_MONTH_DAY} -O $OUT
  year=$( echo $YEAR_MONTH_DAY | cut -c 1-4 )
  month=$( echo $YEAR_MONTH_DAY | cut -c 5-6 )
  day=$( echo $YEAR_MONTH_DAY | cut -c 7-8 ) 
  hour=$( grep grb $OUT | cut -c 46-47 | tail -1 )
}

get_Qq () {
  # q and Q are 3 hour periods
  q=$(( $hour/3 ))
  Q=$(( $HOUR/3 + 1 )) # Forecast
}

last_day_of_month() {
  # cal month year
  LAST_DAY_OF_MONTH=$( echo $( cal $1 $2 ) | tr ' ' '\012' | tail -1 )
}

format() {
  FC=$(( $1*3 ))
  # FC is to have 3 digits
  while [ $( echo $FC | wc -m ) -lt 4 ]; do
    FC=0${FC}
  done
}

download() {
  cd
  [ -d $ARCHIVE ] || mkdir $ARCHIVE
  cd $ARCHIVE
  if [ ! -e $DL ]; then
    wget $U \
      "$URL/$YEAR_MONTH/$YEAR_MONTH_DAY/$DL"
    rm -f data.grb2
    ln -s $DL data.grb2
    # Synchronise the other node
    # rsync -avz -e ssh ${ARCHIVE}/ sb2:${ARCHIVE}/
  else echo -e "Grib data already downloaded before, not downloading.\n"
  fi
}

ARCHIVE=${ARCHIVE:-$HOME/grib}
URL=${URL:-https://nomads.ncdc.noaa.gov/data/gfs-avn-hi}
TMP=${TMP:-/tmp/.grib}
OUT=${OUT:-index.html}

DAY=$( date -u +%d )
HOUR=$( date -u +%k )
MINUTE=$( date -u +%M )

rm -rf $TMP
mkdir $TMP
cd $TMP
[ "$1" = -q ] && get_dates quiet || get_dates
get_Qq

# Calculate how many days we have to go back
DIFF_DAY=$( expr "$DAY" - "$day" )
if [ "$DIFF_DAY" -lt 0 ]; then
  last_day_of_month $month $year
  DIFF_DAY=$( expr "$DIFF_DAY" + "$LAST_DAY_OF_MONTH" )
fi
[ "$DIFF_DAY" -ge 10 ] && echo "DIFF_DAY overflow" && exit 2

# Calculate how many 3 hours we have to go back
DIFF_Q=$(( $Q+8*$DIFF_DAY-$q ))
# If DIFF_Q > 90; then exit as this is the maximum available prediction
[ "$DIFF_Q" -gt 90 ] && echo "DIFF_Q overflow" && exit 3
 
format $DIFF_Q
DL=gfs_3_${year}${month}${day}_${hour}00_${FC}.grb2
download
