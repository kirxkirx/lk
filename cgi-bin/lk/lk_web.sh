#!/usr/bin/env bash

# This script is supposed to be run by process_lightcurve.py

# set custom LD_LIBRARY_PATH - useful when GSL has been compiled manually rather than installad via a package manager
if [ -d /usr/local/lib ];then
 if [ -z "$LD_LIBRARY_PATH" ];then
  export LD_LIBRARY_PATH="/usr/local/lib"
 else
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"
 fi
fi

####### Test that all external programs are available
for TESTED_PROGRAM in readlink basename dirname awk df grep head tail ls sort cat file timeout gnuplot tar gzip ;do
 if ! command -v $TESTED_PROGRAM &>/dev/null ;then
  echo "<html>
<pre>
ERROR: $TESTED_PROGRAM is not found
</pre>
</html>
" > index.html
  exit 1
 fi
done

####### Test internal binaries
for TESTED_PROGRAM in compute_periodogram_allmethods find_peaks hms2deg print_lightcurve_stats ;do
 if ! command -v $TESTED_PROGRAM &>/dev/null ;then
  echo "<html>
<pre>
ERROR: $TESTED_PROGRAM is not found - did you forget to run 'make'?
</pre>
</html>
" > index.html
  exit 1
 fi
done


# Check that this script is not run directly via cgi
BASENAME_CGI_SCRIPT=$(basename "$SCRIPT_NAME")
BASENAME_THIS_SCRIPT=$(basename "$0")
if [ "$BASENAME_CGI_SCRIPT" = "$BASENAME_THIS_SCRIPT" ];then
 exit 1
fi
#

sanitize_filepath() {
    local filename="$1"

    # Replace spaces with underscores
    filename="${filename// /_}"

    # Remove all characters except alphanumeric, dots, underscores, and dashes
    filename="${filename//[^a-zA-Z0-9._/-]/}"

    # Optional: Enforce a maximum length for the file name (e.g., 255 characters)
    local max_length=255
    if [ "${#filename}" -gt "$max_length" ]; then
        filename="${filename:0:max_length}"
    fi

    echo "$filename"
}


####### Begin setup
REAL_SCRIPT_PATH=$(readlink -f "$0")
REAL_SCRIPT_NAME=$(basename "$REAL_SCRIPT_PATH")
REAL_SCRIPT_DIR=$(dirname "$REAL_SCRIPT_PATH")
REAL_TAI_MINUS_UTC_FILE_PATH="$REAL_SCRIPT_DIR/heliocentric_correction/tai-utc.dat"
PROGRAM_TIMEOUT_SECONDS=900

PROTOCOL="http"
# Check if the script was accessed via HTTPS
if [ "$REQUEST_SCHEME" = "https" ]; then
 # Apache web server sets REQUEST_SCHEME=https
 PROTOCOL="https"
elif [ "$HTTPS" = "on" ]; then
 # nginx 
 PROTOCOL="https"
elif echo "$HTTP_REFERER" | grep --quiet 'https:' ; then
 # Alternatively, check where we are coming from - python web server sets HTTP_REFERER=https://...
 PROTOCOL="https"
fi

####### Parse command line arguments
LIGHTCURVEFILE="$1"
if [ -z "$LIGHTCURVEFILE" ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LIGHTCURVEFILE is not set
</pre>
</html>
" > lk_web.log
 exit 1
fi

if [[ "$LIGHTCURVEFILE" == *".."* ]]; then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LIGHTCURVEFILE value is very suspicious
</pre>
</html>
" > lk_web.log
 exit 1
fi

# The work directory should be files/lkNNNNNN
echo "$LIGHTCURVEFILE" | grep --quiet 'files/lk'
if [ $? -ne 0 ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LIGHTCURVEFILE value points to an unexpected path
</pre>
</html>
" > lk_web.log
 exit 1
fi

SANITIZED_FILEPATH=$(sanitize_filepath "$LIGHTCURVEFILE")
if [ "$LIGHTCURVEFILE" != "$SANITIZED_FILEPATH" ]; then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: funny filename #$LIGHTCURVEFILE# #$SANITIZED_FILEPATH#
</pre>
</html>
" > lk_web.log
 exit 1
fi

LCFILE=$(basename "$SANITIZED_FILEPATH")
if [ -z "$LCFILE" ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE is not set
</pre>
</html>
" > lk_web.log
 exit 1
fi

DIRNAME=$(dirname "$SANITIZED_FILEPATH")
if [ -z "$DIRNAME" ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: DIRNAME is not set
</pre>
</html>
" > lk_web.log
 exit 1
fi

PMAX="$2"
if [ -z "$PMAX" ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: PMAX is not set
</pre>
</html>
" > lk_web.log
 exit 1
fi


PMIN="$3"
if [ -z "$PMIN" ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: PMIN is not set
</pre>
</html>
" > lk_web.log
 exit 1
fi


PSHIFT="$4"
if [ -z "$PSHIFT" ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: PSHIFT is not set
</pre>
</html>
" > lk_web.log
 exit 1
fi


JDMIN="$5"
JDMAX="$6"
JOBID="$7"
JD0MANUAL="$8"
PMANUAL="$9"

####### Set color scheme for gnuplot 5.0 or above
GNUPLOT5_COLOR_SCHEME_COMMAND="set colors classic"
GNUPLOT_VERSION=$(gnuplot --version | awk '{print $2}' | awk '{print $1}' FS='.')
if [ $GNUPLOT_VERSION -ge 5 ];then
 COLOR_SCHEME_COMMAND="$GNUPLOT5_COLOR_SCHEME_COMMAND"
else
 COLOR_SCHEME_COMMAND=""
fi
#######

echo "############## $0 ##############" 

# Check if the lightcurve file was actually uploaded
if [ ! -f "$SANITIZED_FILEPATH" ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: $SANITIZED_FILEPATH does not exist
</pre>
</html>
" > lk_web.log
 exit 1
fi
if [ ! -s "$SANITIZED_FILEPATH" ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: $SANITIZED_FILEPATH is empty
</pre>
</html>
" > lk_web.log
 exit 1
fi
# check the actual content of the input file
file "$SANITIZED_FILEPATH" | grep --quiet 'text'
if [ $? -ne 0 ];then
 echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: $SANITIZED_FILEPATH does not seem to contain lightcurve data in text format
</pre>
</html>
" > lk_web.log
 if [ -f "$SANITIZED_FILEPATH" ];then
  rm -f "$SANITIZED_FILEPATH"
 fi
 exit 1
fi

# Make up tar archive name
TAR_ARCHIVE_NAME="$(basename $DIRNAME).tar.gz"

# Change to the work directory
echo "Changing to the working directory $DIRNAME" 
cd "$DIRNAME" || exit 1

# Set phase range
echo "Setting the phase range for plots"  
PHASE_RANGE_TYPE=1
PHASE_RANGE="[-0.55:1.05]"
if [ -f phaserange_type.input ];then
 PHASE_RANGE_TYPE=$(cat phaserange_type.input)
 if [ "$PHASE_RANGE_TYPE" == "1" ];then
  PHASE_RANGE="[-0.55:1.05]"
 elif [ "$PHASE_RANGE_TYPE" == "2" ];then
  PHASE_RANGE="[-0.05:2.05]"
 elif [ "$PHASE_RANGE_TYPE" == "3" ];then
  PHASE_RANGE="[-0.05:1.05]"
 else
  PHASE_RANGE_TYPE=1
 fi
fi
# Save phase range to file for find_point to read
echo "$PHASE_RANGE" > phase_range.txt
#cat phase_range.txt 

# If the lightcurve file has just been uploaded...
if [ ! -f lightcurve.dat ];then
 
 echo "The lightcurve file has just been uploaded (this is the first run)" 

 # Check if there is still enough space on the device that keeps results
 echo "Checking free disk space" 
 FILES_DIR=".."
 DISK_USAGE_PERCENT=$(df "$FILES_DIR/" | grep -v "Use" | head -n1 | awk '{print $5}')
 DISK_USAGE_PERCENT=${DISK_USAGE_PERCENT/'%'/}
 echo "Determined disk usage $DISK_USAGE_PERCENT%" 
 if [ $DISK_USAGE_PERCENT -gt 90 ];then
  OLDEST_DIR=$(ls --sort=time "$FILES_DIR/" | tail -n1)
  # If the oldest directory is not the same as the current directory
  CURRENTDIR=$(basename $DIRNAME)
  CURRENTDIR="../$CURRENTDIR"
  if [ "$FILES_DIR/$OLDEST_DIR" != "$CURRENTDIR" ];then
   # REMOVE THE OLDEST DIRECTORY
   echo "Removing the old directory $FILES_DIR/$OLDEST_DIR to free-up disk space" 
   if [ -n "$FILES_DIR" ] && [ -n "$OLDEST_DIR" ];then
    rm -rf "${FILES_DIR:?}/${OLDEST_DIR:?}"
   fi
  fi
 fi

 if [ ! -f "$LCFILE" ];then
  echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: the input lightcurve file $LCFILE does not exist
</pre>
</html>
" > index.html
  exit 1
 fi

 if [ ! -s "$LCFILE" ];then
  echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: the input lightcurve file $LCFILE is empty
</pre>
</html>
" > index.html
  exit 1
 fi

 if [ -x "$LCFILE" ];then
  echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: the input lightcurve file $LCFILE is marked as executable
</pre>
</html>
" > index.html
  exit 1
 fi

 # Check if the file is in Catalina CSV format
 echo "Checking if the input lightcurve file is in Catalina or ASAS-SN CSV format" 
 if grep --quiet "MasterID" $LCFILE ;then
  # Re-format Catalina CSV to simple ASCII
  echo "Re-formatting the lightcurve file" 
  cat "$LCFILE" | grep -v "MasterID" | awk '{printf "%.5f %6.3f %5.3f\n",$6+2400000.5,$2,$3}' FS=',' | sort -n > catalina_csv_to_ascii.dat
  LCFILE=catalina_csv_to_ascii.dat
 elif grep --quiet -e "HJD,UT" -e "ASAS-SN SkyPatrol ID" $LCFILE ;then
  # Re-format ASAS-SN CSV it to simple ASCII
  echo "Re-formatting the lightcurve file" 
  # if this is ASAS-SN v1 CSV
  grep --quiet "HJD,UT" $LCFILE
  if [ $? -eq 0 ];then
   cat "$LCFILE" | grep -v "HJD,UT" | grep -v -e '>' -e '99.990' | grep ',V' | awk '{printf "%.5f %6.3f %5.3f\n",$1,$6,$7}' FS=',' | sort -n > asassn_V_csv_to_ascii.dat
   cat "$LCFILE" | grep -v "HJD,UT" | grep -v -e '>' -e '99.990' | grep ',g' | awk '{printf "%.5f %6.3f %5.3f\n",$1,$6,$7}' FS=',' | sort -n > asassn_g_csv_to_ascii.dat
  else
   grep --quiet "ASAS-SN SkyPatrol ID" $LCFILE
   if [ $? -eq 0 ];then
    cat "$LCFILE" | grep "," | grep -v -e 'JD,Flux' -e '>' -e '99.990' | grep ',V' | awk '{printf "%.5f %6.3f %5.3f\n",$1,$4,$5}' FS=',' | sort -n > asassn_V_csv_to_ascii.dat
    cat "$LCFILE" | grep "," | grep -v -e 'JD,Flux' -e '>' -e '99.990' | grep ',g' | awk '{printf "%.5f %6.3f %5.3f\n",$1,$4,$5}' FS=',' | sort -n > asassn_g_csv_to_ascii.dat
   else
    echo "$0 ERROR: cannot recognize ASAS-SN CSV format" 
   fi
  fi
  if [ -s "asassn_V_csv_to_ascii.dat" ];then
   cp -v asassn_V_csv_to_ascii.dat asassn_csv_to_ascii.dat
  fi
  if [ -s "asassn_g_csv_to_ascii.dat" ];then
   if [ -s "asassn_V_csv_to_ascii.dat" ];then
    if [ -f asassnband_1.input ];then
     # Combine V and g-band lightcurves
     echo "Combining ASAS-SN V and g band lightcurves" 
     MEDIAN_V=$(cat asassn_V_csv_to_ascii.dat | awk '{print $2}' | colstat 2>&1 | grep '= ' | grep 'MEAN=' | awk '{printf "%f", $2}')
     MEDIAN_g=$(cat asassn_g_csv_to_ascii.dat | awk '{print $2}' | colstat 2>&1 | grep '= ' | grep 'MEAN=' | awk '{printf "%f", $2}')
     echo "MEDIAN_V=$MEDIAN_V MEDIAN_g=$MEDIAN_g" 
     cat asassn_g_csv_to_ascii.dat | awk "{printf \"%.5f %6.3f %5.3f\n\",\$1,\$2-$MEDIAN_g+$MEDIAN_V,\$3}" >> asassn_csv_to_ascii.dat
    elif [ -f asassnband_3.input ];then
     # output only g-band lightcurve
     cp -v asassn_g_csv_to_ascii.dat asassn_csv_to_ascii.dat
    fi
   else
    # just output g-band lightcurve
    cp -v asassn_g_csv_to_ascii.dat asassn_csv_to_ascii.dat
   fi
  fi
  LCFILE="asassn_csv_to_ascii.dat"
 fi
 # Ensure the lightcurve file has the correct format suitable for lk_compute_periodogram
 echo "Running lightcurve file sanitizer" 
 formater_out_wfk "$LCFILE" > lightcurve.dat
 if [ $? -ne 0 ];then
  echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: cannot parse $LCFILE
(non-zero exit status of 'formater_out_wfk')
</pre>
</html>
" > index.html
  if [ -f "$LCFILE" ];then
   rm -f "$LCFILE"
  fi
  exit 1
 fi
 # always delete the original lightcurve file for security reasons
 # keep only the copy that was sanitized by formater_out_wfk
 if [ -f "$LCFILE" ];then
  rm -f "$LCFILE"
 fi
 #
 if [ ! -s lightcurve.dat ];then
  echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: cannot parse $LCFILE
(the output 'lightcurve.dat' is empty)
</pre>
</html>
" > index.html
  exit 1
 fi
 # Apply Heliocentric correction if needed
 APPLYHELCOR=$(cat time_conversion.txt | awk '{print $1}')
 TIMESYS=$(cat time_conversion.txt | awk '{print $2}')
 RAHMS=$(cat time_conversion.txt | awk '{print $3}')
 DECDMS=$(cat time_conversion.txt | awk '{print $4}')
 echo "APPLYHELCOR = $APPLYHELCOR
TIMESYS = $TIMESYS
RAHMS = $RAHMS
DECDMS = $DECDMS" 
 if [ "$APPLYHELCOR" == "Yes" ];then
  echo "APPLYING HELIOCENTRIC CORRECTION" 
  # Convert HMS to decimal degrees
  POSITION_DECIMAL_DEG=$(hms2deg "$RAHMS" "$DECDMS")
  if [ "$POSITION_DECIMAL_DEG" == "" ];then
  echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: cannot convert $RAHMS $DECDMS to decimal degrees/
</pre>
</html>
" > index.html
    exit 1
  fi
  # Prepare tai-utc.dat file
  mkdir heliocentric_correction/
  if [ $? -ne 0 ];then
  echo "<html>
<pre>
$REAL_SCRIPT_NAME ERROR: cannot mkdir heliocentric_correction/
</pre>
</html>
" > index.html
   exit 1
  fi
  # Check if the file is in the right place
  if [ -f "$REAL_TAI_MINUS_UTC_FILE_PATH" ];then
   # Copy tai-utc.dat file
   cp -v "$REAL_TAI_MINUS_UTC_FILE_PATH" heliocentric_correction/
  else
   echo "<html>
<pre>  
$REAL_SCRIPT_NAME ERROR: cannot find file $REAL_TAI_MINUS_UTC_FILE_PATH
</pre>  
</html>  
" > index.html  
   exit 1
  fi
  hjd_input_in_"$TIMESYS" lightcurve.dat $POSITION_DECIMAL_DEG &>> program.log
  if [ $? -ne 0 ];then
   echo "<html>
<pre>  
$REAL_SCRIPT_NAME ERROR: hjd_input_in_$TIMESYS lightcurve.dat $POSITION_DECIMAL_DEG returned non-zero exit status
</pre>  
</html>  
" > index.html
   exit 1
  fi
  if [ -f lightcurve.dat_hjdTT ];then
   cp -v lightcurve.dat_hjdTT lightcurve.dat &>> program.log
  else
   echo "<html>
<pre>  
$REAL_SCRIPT_NAME ERROR: hjd_input_in_$TIMESYS did not create lightcurve.dat_hjdTT file!
</pre>  
</html>  
" > index.html
   exit 1
  fi
 fi
fi

# reset LCFILE once and for all
LCFILE=lightcurve.dat

echo "Setting JD0" 
# Get JD0 (brightest or faintest point)
if [ -n "$JD0MANUAL" ];then
 JD0=$JD0MANUAL
# echo "########### JD0MANUAL ###########"
else
 # Try to guess if this is an eclipsing binary (with sharp minima) or not
 cat "$LCFILE" | awk '{print $2}' | colstat 2>&1 | grep '= ' > lightcurve.stat
 if [ $? -ne 0 ];then
  echo "<html>
<pre>  
$REAL_SCRIPT_NAME ERROR: cat $LCFILE | awk '{print \$2}' | colstat > lightcurve.stat returned non-zero exit status.
Aborting further computations.

The log output is:"  > index.html
cat program.log >> index.html
echo "</pre>  
</html>  
" >> index.html
   exit 1
 fi
 MEDIAN_MAG=$(cat lightcurve.stat | grep 'MEDIAN= ' | awk '{print $2}')
 MEAN_MAG=$(cat lightcurve.stat | grep 'MEAN= ' | awk '{print $2}')
 MEAN_MAG_ERR=$(cat lightcurve.stat | grep 'MEAN_ERR= ' | awk '{print $2}')
 TEST=$(echo "$MEDIAN_MAG $MEAN_MAG $MEAN_MAG_ERR" | awk '{if ( ($1-$2)/$3 < -3.0 ) print 1 ;else print 0 }')
 if [ -z "$TEST" ];then
  echo "<html>
<pre>  
$REAL_SCRIPT_NAME ERROR: empty TEST variable after
TEST=$(echo \"$MEDIAN_MAG $MEAN_MAG $MEAN_MAG_ERR\" | awk '{if ( (\$1-\$2)/\$3 < -3.0 ) print 1 ;else print 0 }')
Aborting further computations.

The log output is:"  > index.html
cat program.log >> index.html
echo "</pre>  
</html>  
" >> index.html
   exit 1
 fi
 if [ $TEST -eq 1 ];then
  # This is eclipsing binary
  # Get JD0 (faintest point)
  JD0=$(cat "$LCFILE" | awk '{print $2" "$1}' | sort -n | tail -n 1 | awk '{printf "%.5f",$2}')
 else
  # Get JD0 (brightest point)
  JD0=$(cat "$LCFILE" | awk '{print $2" "$1}' | sort -n | head -n 1 | awk '{printf "%.5f",$2}')
 fi
# echo "########### JD0 ###########"
fi
echo "$JD0" > jd0.txt
cat jd0.txt 

ORIGINALLIGHTCURVEFILE="lightcurve_data.txt"
EDITEDLIGHTCURVEFILE=edited_"$ORIGINALLIGHTCURVEFILE"
if [ ! -h "$EDITEDLIGHTCURVEFILE" ];then
 ln -s "$LCFILE" "$EDITEDLIGHTCURVEFILE"
fi
LCSTATS=$(print_lightcurve_stats "$LCFILE" "$JDMIN" "$JDMAX")

if [ -z "$PMANUAL" ];then
 # Remove period range file if exist from a previous run
 if [ -f lk_period_search_range.txt ];then
  rm -f lk_period_search_range.txt
 fi
 echo "Computing periodograms" 
 # Simultaneously compute both LK and DFT periodograms
 timeout $PROGRAM_TIMEOUT_SECONDS compute_periodogram_allmethods "$LCFILE" "$PMAX" "$PMIN" "$PSHIFT" &>> program.log 
 # Check exit status
 if [ $? -ne 0 ];then
  # If the command times out, timeout will exit with status 124. (from 'man timeout')
  # some problem here
   echo "<html>
<pre>  
$REAL_SCRIPT_NAME ERROR: lk_compute_periodogram $LCFILE $PMAX $PMIN $PSHIFT returned non-zero exit status.
Aborting further computations.

Most likely the limit on computing time of $PROGRAM_TIMEOUT_SECONDS seconds was reached.
Please try searching in a narrower trial period range or with a larger phase offset.

It is also possible that the input parameters (pmax, pmin, step) were incorrect or the lightcurve file is corrupted.

The log output is:"  > index.html
cat program.log >> index.html
echo "</pre>  
</html>  
" >> index.html
   exit 1
 fi
 # If lk_compute_periodogram had to override the period range input by user
 if [ -f lk_period_search_range.txt ];then
  PMAX=$(cat lk_period_search_range.txt | awk '{print $1}')
  PMIN=$(cat lk_period_search_range.txt | awk '{print $2}')
 fi
 timeout $PROGRAM_TIMEOUT_SECONDS find_peaks lk.periodogram | awk '{print $2" "$1}' | sort -rnu | head -n10 | awk '{print $1" "$2}' > highest_peaks.txt
 # Check exit status
 if [ $? -ne 0 ];then
  # If the command times out, timeout will exit with status 124. (from 'man timeout')
  # some problem here
   echo "<html>
<pre>  
$REAL_SCRIPT_NAME ERROR: find_peaks find_peaks lk.periodogram | awk '{print \$2\" \"\$1}' | sort -rnu | head -n10 | awk '{print \$1\" \"\$2}' > highest_peaks.txt returned non-zero exit status.
Aborting further computations.
</pre>  
</html>  
" > index.html
   exit 1
 fi
 FREQ=$(cat highest_peaks.txt | head -n 1 |awk '{print $2}')
 PMANUAL=$(echo "$FREQ" |awk '{printf "%.7f",1.0/$1}')
 timeout $PROGRAM_TIMEOUT_SECONDS find_peaks deeming.periodogram | awk '{print $2" "$1}' | sort -rnu | head -n10 | awk '{print $1" "$2}' > highest_peaks_deeming.txt
 # Check exit status
 if [ $? -ne 0 ];then
  # If the command times out, timeout will exit with status 124. (from 'man timeout')
  # some problem here
   echo "<html>
<pre>  
$REAL_SCRIPT_NAME ERROR: find_peaks find_peaks deeming.periodogram | awk '{print \$2\" \"\$1}' | sort -rnu | head -n10 | awk '{print \$1\" \"\$2}' > highest_peaks.txt returned non-zero exit status.
Aborting further computations.
</pre>  
</html>  
" > index.html
   exit 1
 fi
else
 # Just get the manually set period
 FREQ=$(echo "$PMANUAL" |awk '{printf "%.7f",1.0/$1}')
 THETA=$(cat highest_peaks.txt | head -n 1 |awk '{print $1}')
 echo "$THETA $FREQ" > highest_peaks.txt  
 THETA=$(cat highest_peaks_deeming.txt | head -n 1 |awk '{print $1}')
 echo "$THETA $FREQ" > highest_peaks_deeming.txt
fi

# Get plot limits
MAG_RANGE=""
if [ -s plot_range.txt ];then
 MAG_RANGE=$(cat plot_range.txt)
fi
LK_PERIODOGRAM_RANGE=""
if [ -s lk_periodogram_range.txt ];then
 LK_PERIODOGRAM_RANGE=$(cat lk_periodogram_range.txt)
fi

# Write gnuplot script for LK periodogram
echo "set term png size 600,350 medium
$COLOR_SCHEME_COMMAND
set output \"lk.png\"
set xlabel \"Frequency [c/d]\"
set ylabel \"1/theta\"
set format y \"%5.2f\"" > lk.gnuplot
echo -n "plot []$LK_PERIODOGRAM_RANGE \"lk.periodogram\" using 1:2 with lines linecolor 3 title \"\"" >> lk.gnuplot
# Run gnuplot later

# Write gnuplot script for lightcurve as a function of time (unfolded)
echo "set term png size 600,350 medium
$COLOR_SCHEME_COMMAND
set output 'lightcurve.png'
set xlabel 'JD-$JD0'
set ylabel 'mag'
set format y '"$(cat plot_format.txt)"'
set xrange "$(cat lightcurve_plot_range.txt)"
set yrange $MAG_RANGE" > lightcurve.gnuplot
echo -n "plot \"$LCFILE\" using (\$1)-$JD0:2 linecolor 2 pointtype 5 pointsize 0.3  title \"\"" >> lightcurve.gnuplot

# Make sure the list of removed points is empty
rm -f -- removed_points.html *.selected
touch removed_points.html

# Start HTML page
echo "
<HTML>
<head>
<style type=\"text/css\">
body { color: #000;
 background: #fff;
 font-family: arial, helvetica, sans-serif;
 font-size: 12pt;
 line-height: 16pt;
 margin-top: 3mm;
 margin-bottom: 3mm;
 margin-left: 10mm;
 margin-right: 10mm;
}
 
p {text-align: justify; text-indent: 6mm; line-height: 16pt}
.code {text-align: left; font-family: courier; background: #ccc; color: #000}
table.main {border-spacing: 5pt}
td { padding-left: 20pt; padding-right: 20pt; padding-bottom: 3pt }

a:link {color: #55f; text-decoration: none}
a:visited {color: #33f; text-decoration: none}
a:active {color: #55f; text-decoration: none}
a:hover {color: #55f; text-decoration: underline}
</style>

<SCRIPT LANGUAGE=\"JavaScript\">
function fn_doubleperiod (form) {
    var TestVar = form.pmanual.value;
    form.pmanual.value = TestVar*2.0;
    form.submit()
}

function fn_halfperiod (form) {
    var TestVar = form.pmanual.value;
    form.pmanual.value = TestVar/2.0;
    form.submit()
}

function fn_setperiod (form,period) {
    form.pmanual.value = period;
}

function fn_improveperiod (form,period) {
    var Factor = 10.0;
    var Freq = 1.0/period;
    var FreqRange = 1.0/form.pmin.value - 1.0/form.pmax.value;
    var FreqOffset = Math.min( 0.05*Freq, FreqRange/Factor);
    var MinFreq = Freq - FreqOffset;
    var MaxFreq = Freq + FreqOffset;
    var pmax = 1.0/MinFreq;
    var pmin = 1.0/MaxFreq;
    form.pmin.value = pmin;
    form.pmax.value = pmax;
    form.phaseshift.value = form.phaseshift.value/Factor;
    form.submit();
}

function fn_estimate_period_accuracy (form,period) {
    var JDRange = form.jdmax.value - form.jdmin.value;
    var DeltaP = 0.5*period*period/JDRange;
    alert(\"The selected period is \" + period.toFixed(8) + \" d, its estimated accuracy is \" + DeltaP.toFixed(8) + \" d.\\nThis error estimation is done as P_error = 0.5 * P^2/JD_range which corresponds \\nto the phase shift of 0.5 over the time range of observations (\" + JDRange.toFixed(2) + \" days).\" )
}

</SCRIPT>


</head>
<CENTER>
<h2>Period search results</h2>
<br>
<form name=\"mainform\" enctype=\"multipart/form-data\" action=\"$PROTOCOL://$HTTP_HOST/cgi-bin/lk/process_lightcurve.py\" method=\"post\">
Max period:&nbsp;<input type=\"text\" name=\"pmax\" value=\"$PMAX\" size=3>d,&nbsp;&nbsp;
Min period:&nbsp;<input type=\"text\" name=\"pmin\" value=\"$PMIN\" size=3>d,&nbsp;&nbsp;
Max phase shift:&nbsp;<input type=\"text\" name=\"phaseshift\" value=\"$PSHIFT\" size=3>&nbsp;&nbsp;  
<input type=\"submit\" value=\"Compute\">
<input type=\"hidden\" name=\"fileupload\" value=\"False\">
<input type=\"hidden\" name=\"jobid\" value=\"$JOBID\">
<input type=\"hidden\" name=\"lcfile\" value=\"$LCFILE\">
<br>
<br>
<TABLE>
<tr><td>Light elements: </td><td align=\"left\">JD0= <input type=\"text\" name=\"jdmanual\" value=\"$JD0\" size=11>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Period= <input type=\"text\" name=\"pmanual\" value=\"$PMANUAL\" size=8>d
<INPUT TYPE=\"button\" NAME=\"doubleperiod\" Value=\"Px2\" onClick=\"fn_doubleperiod(this.form)\">
<INPUT TYPE=\"button\" NAME=\"doubleperiod\" Value=\"P/2\" onClick=\"fn_halfperiod(this.form)\">
</td>
</tr>

<input type=\"hidden\" name=\"previouspmanual\" value=\"$PMANUAL\">
<input type=\"hidden\" name=\"previoujdmanual\" value=\"$JD0\">
<tr><td>Time range: </td><td align=\"left\">&nbsp;&nbsp;&nbsp;&nbsp;JD 
<input type=\"text\" name=\"jdmin\" value=\""$(cat lightcurve_range.txt | awk '{print $1}')"\" size=11>
&nbsp;-&nbsp;
<input type=\"text\" name=\"jdmax\" value=\""$(cat lightcurve_range.txt | awk '{print $2}')"\" size=11>
</td>
</tr>
</TABLE>
<font style=\"font-size:x-small;color:#A0A0A0;\">
Note, you'll need to <a style=\"font-size:x-small;color:#A0A0A0;\" href=\"$PROTOCOL://$HTTP_HOST/lk\">re-upload the lightcurve file</a> to get back to the full JD range after exploring a limited one.
</font>
" > index.html
# note awk '{print $1}' and awk '{print $2}' above!

if [ "$PHASE_RANGE_TYPE" == "3" ];then
 echo "<br><br>Phase range for plots: <input type=\"radio\" name=\"phaserange\" value=\"1\">&nbsp;-0.5 to 1.0&nbsp;&nbsp;&nbsp;<input type=\"radio\" name=\"phaserange\" value=\"2\">&nbsp;0.0 to 2.0&nbsp;&nbsp;&nbsp;<input type=\"radio\" name=\"phaserange\" value=\"3\" checked>&nbsp;0.0 to 1.0"  >> index.html
elif [ "$PHASE_RANGE_TYPE" == "2" ];then
 echo "<br><br>Phase range for plots: <input type=\"radio\" name=\"phaserange\" value=\"1\">&nbsp;-0.5 to 1.0&nbsp;&nbsp;&nbsp;<input type=\"radio\" name=\"phaserange\" value=\"2\" checked>&nbsp;0.0 to 2.0&nbsp;&nbsp;&nbsp;<input type=\"radio\" name=\"phaserange\" value=\"3\">&nbsp;0.0 to 1.0"  >> index.html
else
 echo "<br><br>Phase range for plots: <input type=\"radio\" name=\"phaserange\" value=\"1\" checked>&nbsp;-0.5 to 1.0&nbsp;&nbsp;&nbsp;<input type=\"radio\" name=\"phaserange\" value=\"2\">&nbsp;0.0 to 2.0&nbsp;&nbsp;&nbsp;<input type=\"radio\" name=\"phaserange\" value=\"3\">&nbsp;0.0 to 1.0"  >> index.html
fi

ORIGINAL_LIGHTCURVE_FILENAME=""
if [ -s "original_lightcurve_filename.txt" ];then
 ORIGINAL_LIGHTCURVE_FILENAME="Input lightcurve data file: <span style=\"color: green;\">$(head -n1 original_lightcurve_filename.txt)</span>"
fi

echo "
</form>

<pre>$ORIGINAL_LIGHTCURVE_FILENAME 
Edited lightcurve data file: <a href=\"$EDITEDLIGHTCURVEFILE\">$EDITEDLIGHTCURVEFILE</a>
$LCSTATS

<!--#include virtual=\"removed_points.html\" -->
</pre>
Please find below the lightcurve (magnitude plotted as a function of time)
as well as phased lightcurves corresponding to the ten highest peaks identified
on <b>Lafler & Kinman and Deeming (DFT)</b> periodograms in the specified trial period range ($PMIN to $PMAX days).
You may remove an outlier lightcurve point by clicking on it in any of the lightcurve plots.
Press \"Compute\" again to re-compute periodograms without the deleted points.
You may <a href=\"$TAR_ARCHIVE_NAME\">download the .tar.gz archive containing this results page</a> and the data files it links to.
The interactive features will not work for the static downloaded copy.
<hr>
<h2>Lafler & Kinman method</h2>
<TABLE width=\"750\">
<tr><th>Lightcurve</th><th>Lafler & Kinman periodogram</th></tr>
<tr>
<td><center>
<A HREF=$PROTOCOL://$HTTP_HOST/cgi-bin/lk/process_click.sh/$DIRNAME/lightcurve.png>
<img src=\"lightcurve.png\" ISMAP></img>
</A>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"$LCFILE\">data</a>&nbsp;&nbsp;&nbsp;" >> index.html
#if [ -f $LCFILE.selected ];then
 echo "<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"$LCFILE.selected\">removed pts.</a>&nbsp;&nbsp;&nbsp;" >> index.html
#fi
echo "<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"lightcurve.gnuplot\">script</a>
</center></td>
<td><center>
<img src=\"lk.png\"></img>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"lk.periodogram\">data</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"lk.gnuplot\">script</a> 
</center></td>
</tr>
" >> index.html


# LK
N=0
cat highest_peaks.txt | while read THETA FREQ ;do
 #N=$[$N+1]
 N=$((N+1))
 
 PERIOD=$(echo "$FREQ" |awk '{printf "%.7f",1.0/$1}')
 
 THETA=$(echo "$THETA" |awk '{printf "%5.2f",$1}')

 # Prepare the data file
 phase_lc "$LCFILE" "$JD0" "$PERIOD" > phase_lc_"$N".dat
 
 # Write gnuplot script
 echo -n "set term png size 600,350 medium
$COLOR_SCHEME_COMMAND
set output 'phase_lc_$N.png'
set xlabel 'Phase'
set ylabel 'mag'
#set title 'JDmax = $JD0 + $PERIOD x E'
set format y '"$(cat plot_format.txt)"'
plot $PHASE_RANGE$MAG_RANGE \"phase_lc_$N.dat\" linecolor 3 pointtype 5 pointsize 0.3 title \"\"" > phase_lc_$N.gnuplot

 # Write gnuplot script to plot periodogram with the current period indicated
 cp lk.gnuplot phase_lc_"$N".lk.gnuplot
 sed -i "s/lk.png/phase_lc_$N.lk.png/" phase_lc_$N.lk.gnuplot
 echo ",\
 \"<echo '$FREQ $THETA'\" with impulses linecolor 1 title \"\"
 " >> phase_lc_"$N".lk.gnuplot

echo "
<tr><td colspan=2>
<CENTER>
<hr>
</CENTER></td></tr>
<td>
<CENTER>JD<sub>max</sub> = $JD0 + $PERIOD x E</br>
<A HREF=$PROTOCOL://$HTTP_HOST/cgi-bin/lk/process_click.sh/$DIRNAME/phase_lc_$N.png>
<img src=\"phase_lc_$N.png\" ISMAP></img>
</A>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.dat\">data</a>&nbsp;&nbsp;&nbsp;" >> index.html
#if [ -f phase_lc_$N.dat.selected ];then
 echo "<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.dat.selected\">removed pts.</a>&nbsp;&nbsp;&nbsp;" >> index.html
#fi
echo "<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.gnuplot\">script</a>
</CENTER>

</td>
<td>
<CENTER>L&K peak $N:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1/&theta; = $THETA&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nu; = $FREQ c/d</br>
<img src=\"phase_lc_$N.lk.png\"></img>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"lk.periodogram\">data</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.lk.gnuplot\">script</a>
</CENTER>
</td></tr>

<tr><td colspan=2>
<CENTER>
<a style=\"font-size:x-small\" href=\"javascript:void(0)\" onClick=\"fn_improveperiod(document.mainform,$PERIOD)\">improve this period</a>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;\" href=\"javascript:void(0)\" onClick=\"fn_setperiod(document.mainform,$PERIOD);fn_estimate_period_accuracy(document.mainform,$PERIOD)\">select this period</a>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small\" href=\"javascript:void(0)\" onClick=\"fn_setperiod(document.mainform,$PERIOD);fn_doubleperiod(document.mainform)\">double this period</a> 
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small\" href=\"javascript:void(0)\" onClick=\"fn_setperiod(document.mainform,$PERIOD);fn_halfperiod(document.mainform)\">halve this period</a>
</CENTER>
</td></tr>

" >> index.html

done

wait

# Deeming

# Write gnuplot script for Deeming periodogram
echo "set term png size 600,350 medium
$COLOR_SCHEME_COMMAND
set output \"deeming.png\"
set xlabel \"Frequency [c/d]\"
set ylabel \"Power\"
set format y \"%5.2f\"" > deeming.gnuplot
echo -n "plot \"deeming.periodogram\" using 1:2 with lines linecolor 3 title \"DFT\", \"deeming.periodogram\" using 1:3 with lines linecolor 2 title \"Window\"" >> deeming.gnuplot
# Run gnuplot later


echo "</TABLE>
<hr>
<h2>Deeming (DFT) method</h2>
<TABLE width=\"750\">
<tr><th>Lightcurve</th><th>Deeming (DFT) periodogram</th></tr>
<tr>
<td><center>
<A HREF=$PROTOCOL://$HTTP_HOST/cgi-bin/lk/process_click.sh/$DIRNAME/lightcurve.png>
<img src=\"lightcurve.png\" ISMAP></img>
</A>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"$LCFILE\">data</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"$LCFILE.selected\">removed pts.</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"lightcurve.gnuplot\">script</a>
</center></td>
<td><center>
<img src=\"deeming.png\"></img>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"deeming.periodogram\">data</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"deeming.gnuplot\">script</a> 
</center></td>
</tr>
 " >> index.html


# Plot lightcurves for N best peaks
N=10
cat highest_peaks_deeming.txt | while read THETA FREQ WINDOW ;do
 #N=$[$N+1]
 N=$((N+1))
 
 PERIOD=$(echo "$FREQ" |awk '{printf "%.7f",1.0/$1}')
 
 THETA=$(echo "$THETA" |awk '{printf "%.8f",$1}')

 # Prepare the data file
 phase_lc "$LCFILE" "$JD0" "$PERIOD" > phase_lc_"$N".dat

 # Write gnuplot script
 echo -n "set term png size 600,350 medium
$COLOR_SCHEME_COMMAND
set output 'phase_lc_$N.png'
set xlabel 'Phase'
set ylabel 'mag'
#set title 'JDmax = $JD0 + $PERIOD x E'
set format y '"$(cat plot_format.txt)"'
plot $PHASE_RANGE$MAG_RANGE \"phase_lc_$N.dat\" linecolor 3 pointtype 5 pointsize 0.3 title \"\"" > phase_lc_$N.gnuplot

 # Write gnuplot script to plot periodogram with the current period indicated
 cp deeming.gnuplot phase_lc_"$N".deeming.gnuplot
 sed -i "s/deeming.png/phase_lc_$N.deeming.png/" phase_lc_$N.deeming.gnuplot
 echo ",\
 \"<echo '$FREQ $THETA'\" with impulses linecolor 1 title \"\"
 " >> phase_lc_"$N".deeming.gnuplot
# gnuplot phase_lc_$N.deeming.gnuplot 

echo "
<tr><td colspan=2>
<CENTER>
<hr>
</CENTER></td></tr>
<td>
<CENTER>JD<sub>max</sub> = $JD0 + $PERIOD x E</br>
<A HREF=$PROTOCOL://$HTTP_HOST/cgi-bin/lk/process_click.sh/$DIRNAME/phase_lc_$N.png>
<img src=\"phase_lc_$N.png\" ISMAP></img>
</A>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.dat\">data</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.dat.selected\">removed pts.</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.gnuplot\">script</a>
</CENTER>

</td>
<td>
<CENTER>DFT peak $((N-10)):&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Power = $THETA&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nu; = $FREQ c/d</br>
<img src=\"phase_lc_$N.deeming.png\"></img>
<!-- <a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.deeming.dat\">data</a>&nbsp;&nbsp;&nbsp; --!>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"deeming.periodogram\">data</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"phase_lc_$N.deeming.gnuplot\">script</a>
</CENTER>
</td></tr>

<tr><td colspan=2>
<CENTER>
<a style=\"font-size:x-small;\" href=\"javascript:void(0)\" onClick=\"fn_improveperiod(document.mainform,$PERIOD)\">improve this period</a>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;\" href=\"javascript:void(0)\" onClick=\"fn_setperiod(document.mainform,$PERIOD);fn_estimate_period_accuracy(document.mainform,$PERIOD)\">select this period</a>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;\" href=\"javascript:void(0)\" onClick=\"fn_setperiod(document.mainform,$PERIOD);fn_doubleperiod(document.mainform)\">double this period</a> 
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;\" href=\"javascript:void(0)\" onClick=\"fn_setperiod(document.mainform,$PERIOD);fn_halfperiod(document.mainform)\">halve this period</a>
</CENTER>
</td></tr>

" >> index.html

done

wait

################# New stuff - plot PSD and window function in loglog scale #################
# Write gnuplot scripts
echo "set term png size 600,350 medium
$COLOR_SCHEME_COMMAND
set output \"psd_loglog.png\"
set xlabel \"Frequency [c/d]\"
set ylabel \"Power\"
set logscale
#set format y \"%5.2f\"" > psd_loglog.gnuplot
echo -n "plot \"deeming.periodogram\" using 1:2 with lines linecolor 3 title \"PSD\"" >> psd_loglog.gnuplot

echo "set term png size 600,350 medium
$COLOR_SCHEME_COMMAND
set output \"window_loglog.png\"
set xlabel \"Frequency [c/d]\"
set ylabel \"Power\"
set logscale
#set format y \"%5.2f\"" > window_loglog.gnuplot
echo -n "plot \"deeming.periodogram\" using 1:3 with lines linecolor 2 title \"Window\"" >> window_loglog.gnuplot
# Run gnuplot later

# Write the corresponding section of the HTML page
echo "</TABLE>
<hr>
<h2>Deeming (DFT) power spectral density (PSD) plotted in loglog scale</h2>
<TABLE width=\"750\">
<tr><th>Window function</th><th>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Deeming (DFT = PSD) periodogram</th></tr>
<tr>
<td><center>
<img src=\"window_loglog.png\"></img>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"deeming.periodogram\">data</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"window_loglog.gnuplot\">script</a>
</center></td>
<td><center>
<img src=\"psd_loglog.png\"></img>
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"deeming.periodogram\">data</a>&nbsp;&nbsp;&nbsp;
<a style=\"font-size:x-small;color:#A0A0A0;\" href=\"psd_loglog.gnuplot\">script</a> 
</center></td>
</tr>
 " >> index.html

############################################################################################


#### DEBUG ####
#echo "SCRIPT_FILENAME = $SCRIPT_FILENAME
#PATH_INFO = $PATH_INFO
#QUERY_STRING = $QUERY_STRING
#SCRIPT_FILENAME = $SCRIPT_FILENAME
#SCRIPT_NAME = $SCRIPT_NAME
#SERVER_NAME = $SERVER_NAME
#HTTP_HOST = $HTTP_HOST
#SERVER_SOFTWARE = $SERVER_SOFTWARE
#"
####

# Finish HTML page 
echo "
</TABLE>
</CENTER>
</HTML>
" >> index.html

chmod +x index.html

# Run gnuplot
NPROC=0
for i in *.gnuplot ;do
 #NPROC=$[$NPROC+1]
 NPROC=$((NPROC+1))
 if [ $NPROC -ge 16 ];then
  NPROC=0
  echo "waiting"
  wait
 fi 
 echo "gnuplot $i"
 gnuplot "$i" &
done

wait

echo "index.html created"

# make or update the download-all archive
if [ -f "$TAR_ARCHIVE_NAME" ];then
 rm -f "$TAR_ARCHIVE_NAME"
fi
cd .. || exit 1
tar -czf "$TAR_ARCHIVE_NAME" $(basename "$TAR_ARCHIVE_NAME" .tar.gz) && mv "$TAR_ARCHIVE_NAME" $(basename "$TAR_ARCHIVE_NAME" .tar.gz)

echo "$TAR_ARCHIVE_NAME created"

# we are done here
exit 0
