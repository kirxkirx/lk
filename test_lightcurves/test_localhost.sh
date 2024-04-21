#!/usr/bin/env bash

PERIOD_SEARCH_SERVER="localhost"

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

RESULTURL=$(curl -H 'Expect:' -F file=@"$TEST_LIGHTCURVE_FILE" -F submit="Compute" -F pmax=100 -F pmin=0.1 -F phaseshift=0.1 -F fileupload="True" -F applyhelcor="No" -F timesys="UTC" -F position="00:00:00.00 +00:00:00.0" "http://$PERIOD_SEARCH_SERVER/cgi-bin/lk/process_lightcurve.py" --user vast48:khyzbaojMhztNkWd 2>/dev/null | grep "The output will be written to" | awk -F"<a" '{print $2}' |awk -F">" '{print $1}' | head -n1)
RESULTURL=${RESULTURL//\"/ }
RESULTURL=`echo $RESULTURL | awk '{print $2}'`
if [ -z "$RESULTURL" ];then
 echo "TEST ERROR: empty RESULTURL"
 exit 1
fi
REMOTE_FREQUENCY_CD=$(curl "$RESULTURL" | grep 'L&K peak 1' | head -n1 | awk -F '&nu; =' '{print $2}'  | awk '{printf "%.4f",$1}')

if [ "$REMOTE_FREQUENCY_CD" != "6.1465" ];then
 echo "TEST ERROR: REMOTE_FREQUENCY_CD $REMOTE_FREQUENCY_CD != 6.1465"
 exit 1
fi

echo "Test passed"
