#!/usr/bin/env bash

is_positive_integer() {
    if [[ $1 =~ ^[0-9]+$ ]]; then
        return 0  # success
    else
        return 1  # failure
    fi
}

is_valid_string() {
    if [[ $1 =~ ^[a-zA-Z0-9_.\ ]+$ ]]; then
        return 0  # The string is valid
    else
        return 1  # The string is invalid
    fi
}


REAL_SCRIPT_PATH=$(readlink -f "$0")
REAL_SCRIPT_NAME=$(basename "$REAL_SCRIPT_PATH")
REAL_SCRIPT_DIR=$(dirname "$REAL_SCRIPT_PATH")
export PATH="$REAL_SCRIPT_DIR:$PATH"

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

# That's for debugging
STRING=$(env)

IMAGE="${REQUEST_URI/$SCRIPT_NAME/}"
IMAGE="${IMAGE/\?/ }"
IMAGE="${IMAGE/\,/ }"
IMAGE="${IMAGE//\// }"
LCFILE="${IMAGE/.png/.dat}"

if ! is_valid_string "$LCFILE" ;then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE seems strange
</pre>
</html>
" 
 exit
fi

DIRNAME=$(echo "$LCFILE" | awk '{print $1"/"$2}')
if [ -z "$DIRNAME" ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: DIRNAME is not set
</pre>
</html>
" 
 exit
fi

echo "$DIRNAME" | grep --quiet 'files/lk'
if [ $? -ne 0 ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: DIRNAME seems strange
</pre>
</html>
" 
 exit
fi
if [[ "$DIRNAME" == *".."* ]]; then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: DIRNAME seems strange
</pre>
</html>
" 
 exit
fi


XCLICK=$(echo "$LCFILE" | awk '{print $4}')
if [ -z "$XCLICK" ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: XCLICK is not set
</pre>
</html>
" 
 exit
fi
if ! is_positive_integer "$XCLICK" ;then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: XCLICK is not a positive integer
</pre>
</html>
" 
 exit
fi

YCLICK=$(echo "$LCFILE" | awk '{print $5}')
if [ -z "$YCLICK" ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: YCLICK is not set
</pre>
</html>
" 
 exit
fi
if ! is_positive_integer "$YCLICK" ;then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: YCLICK is not a positive integer
</pre>
</html>
" 
 exit
fi


LCFILE=$(echo "$LCFILE" | awk '{print $3}')
if [ -z "$LCFILE" ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE is not set
</pre>
</html>
" 
 exit
fi
if ! is_valid_string "$LCFILE" ;then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE(2) seems strange
</pre>
</html>
" 
 exit
fi
echo "$LCFILE" | grep --quiet '.dat'
if [ $? -ne 0 ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE seems strange
</pre>
</html>
" 
 exit
fi
if [[ "$LCFILE" == *".."* ]]; then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE seems strange
</pre>
</html>
" 
 exit
fi



cd "$DIRNAME" || exit 1

# check that the lightcurve file is here
if [ ! -f "$LCFILE" ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE is not found
</pre>
</html>
" 
 exit
fi
if [ ! -s "$LCFILE" ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE is empty
</pre>
</html>
" 
 exit
fi
file "$LCFILE" | grep --quiet 'text'
if [ $? -ne 0 ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: LCFILE content seems strange
</pre>
</html>
" 
 exit
fi

# Get JD0 (brightest point) 
if [ ! -s jd0.txt ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: JD0 error
</pre>
</html>
" 
 exit
fi
JD0=$(cat jd0.txt)
if [ -z "$JD0" ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: JD0 is not set
</pre>
</html>
" 
 exit
fi

#RESULT=$(find_point $PARAMS 2>&1 | grep -v 'bestx=')
RESULT=$(find_point "$LCFILE" "$XCLICK" "$YCLICK" 2>&1 | grep -v 'bestx=')
if [ -z "$RESULT" ];then
 echo "Content-Type: text/html

<html>
<pre>
$REAL_SCRIPT_NAME ERROR: RESULT is not set
</pre>
</html>
" 
 exit
fi


# Re-plot all lightcurves
rm -f phase_lc_?.png phase_lc_??.png lightcurve.png
for i in phase_lc_?.gnuplot phase_lc_??.gnuplot lightcurve.gnuplot ;do
 SELECTEDFILENAME=$(basename "$i" .gnuplot).dat.selected
 if [ -f "$SELECTEDFILENAME" ];then
  if ! grep "$SELECTEDFILENAME" $i &>/dev/null ;then
   if [ "$SELECTEDFILENAME" == "lightcurve.dat.selected" ];then
    echo ", \"$SELECTEDFILENAME\" using (\$1)-$JD0:2 linecolor 1 pointtype 5 pointsize 0.3 title \"\"" >> "$i"
   else
    echo ", \"$SELECTEDFILENAME\" linecolor 1 pointtype 5 pointsize 0.3 title \"\"" >> "$i"
   fi
  fi
 fi

 gnuplot "$i" &
done

echo "Removed points:
 JD         mag" > removed_points.html  
cat lightcurve.dat.selected >> removed_points.html

wait

echo "Content-Type: text/html

<html>
<head>
<meta http-equiv=\"Refresh\" content=\"0; url=$PROTOCOL://$HTTP_HOST/lk/$DIRNAME/\"> 
</head>
</html>
"
exit 

# The following is for testing (comment-out the exit above to see this)
echo "Content-Type: text/html

<html>
<pre>
$QUERY_STRING
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
url=$PROTOCOL://$HTTP_HOST/lk/$DIRNAME/
###############################
$IMAGE
$LCFILE
DIRNAME=$DIRNAME
COMMAND find_point $LCFILE $XCLICK $YCLICK
$RESULT
###############################
$STRING
</pre>
</html>
"
