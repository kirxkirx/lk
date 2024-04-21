#!/usr/bin/env bash

PERIOD_SEARCH_SERVER="localhost"

# This function will test if an
is_valid_png_url() {
  url="$1"
  
  # Send a HEAD request to the URL and check the Content-Type header
  content_type=$(curl -sIL "$url" | awk '/Content-Type:/ {print $2}' | tr -d '\r')
  
  # Check if the Content-Type is PNG
  if [[ "$content_type" == "image/png" ]]; then
    # Download the file and check its type using the file utility
    file_type=$(curl -sL "$url" | file --brief --mime-type -)
    
    if [[ "$file_type" == "image/png" ]]; then
      echo "Valid PNG"
      return 0  # Valid PNG
    fi
  fi
  
  return 1  # Not a valid PNG
}

# Test the front page
curl http://"$PERIOD_SEARCH_SERVER"/lk/ | grep 'multipart/form-data' | grep 'cgi-bin/lk/process_lightcurve.py'
if [ $? -ne 0 ];then
 echo "TEST ERROR: cannot access the front web page"
 exit 1
fi

# Upload test lightcurve for period search
TEST_LIGHTCURVE_FILE="test_lightcurves/gsc0437200577.txt"
if [ -f gsc0437200577.txt ];then
 TEST_LIGHTCURVE_FILE="gsc0437200577.txt"
fi

if [ ! -f "$TEST_LIGHTCURVE_FILE" ];then
 echo "TEST ERROR: no test file "$TEST_LIGHTCURVE_FILE""
 exit 1
fi

# Get the results page URL
RESULTURL=$(curl -H 'Expect:' -F file=@"$TEST_LIGHTCURVE_FILE" -F submit="Compute" -F pmax=100 -F pmin=0.1 -F phaseshift=0.1 -F fileupload="True" -F applyhelcor="No" -F timesys="UTC" -F position="00:00:00.00 +00:00:00.0" "http://$PERIOD_SEARCH_SERVER/cgi-bin/lk/process_lightcurve.py" --user vast48:khyzbaojMhztNkWd 2>/dev/null | grep "The output will be written to" | awk -F"<a" '{print $2}' |awk -F">" '{print $1}' | head -n1)
RESULTURL=${RESULTURL//\"/ }
RESULTURL=`echo $RESULTURL | awk '{print $2}'`
if [ -z "$RESULTURL" ];then
 echo "TEST ERROR: empty RESULTURL"
 exit 1
fi
echo "RESULTURL= $RESULTURL"

# Get the results page and see if the frequency of the highest LK peak looks correct
REMOTE_FREQUENCY_CD=$(curl "$RESULTURL" | grep 'L&K peak 1' | head -n1 | awk -F '&nu; =' '{print $2}'  | awk '{printf "%.4f",$1}')
if [ "$REMOTE_FREQUENCY_CD" != "6.1465" ];then
 echo "TEST ERROR: REMOTE_FREQUENCY_CD $REMOTE_FREQUENCY_CD != 6.1465"
 exit 1
fi

# Check if the png plots are actually produced
if ! is_valid_png_url "${RESULTURL/index.html/phase_lc_1.png}" ;then
 echo "TEST ERROR: no PNG phase plot"
 exit 1
fi

echo "Test passed"
