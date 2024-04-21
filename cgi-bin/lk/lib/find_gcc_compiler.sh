#!/usr/bin/env bash
#
# This small script is used in Makefile
# It tries to find Fortran and C++ compilers
#

CC="gcc"
CXX="g++"
FC="gfortran"
RPATH_OPTION=""

SCRIPT_NAME=`basename $0`


LOCAL_GCC=`ls /usr/local/bin/gcc?? 2>/dev/null | tail -n1`
if [ "$LOCAL_GCC" != "" ];then
 if [ -x "$LOCAL_GCC" ];then
  CC="$LOCAL_GCC"
  LOCAL_GFORTRAN=`ls /usr/local/bin/gfortran?? | tail -n1`
  RPATH_OPTION=`ls -d /usr/local/lib/gcc?? | tail -n1`
  if [ -x "$LOCAL_GFORTRAN" ];then
   FC="$LOCAL_GFORTRAN"
   if [ "$SCRIPT_NAME" = "find_gcc_compiler.sh" ];then
    echo "$CC"
   elif [ "$SCRIPT_NAME" = "find_rpath.sh" ];then
    echo "-rpath $RPATH_OPTION"
   elif [ "$SCRIPT_NAME" = "find_cpp_compiler.sh" ];then
    LOCAL_CXX=`ls /usr/local/bin/g++?? | tail -n1`
    if [ -x "$LOCAL_CXX" ];then
     CXX="$LOCAL_CXX"
    fi
    echo "$CXX"
   else
    echo "$FC"
   fi
   exit 0 # we are OK
  else
   # No local gfortran - don't use local gcc
   CC="gcc"
  fi
 fi
fi

GCC_MAJOR_VERSION=`$CC -dumpversion | cut -f1 -d.`
if [ $GCC_MAJOR_VERSION -lt 4 ];then
 FC="g77"
else
 FC="gfortran"
 # Do not perform gcc/g77 versions match check - it's too complex and who needs gcc-3.x anyway?
fi

if [ "$SCRIPT_NAME" = "find_gcc_compiler.sh" ];then
 echo "$CC"
elif [ "$SCRIPT_NAME" = "find_cpp_compiler.sh" ];then
 echo "$CXX"
elif [ "$SCRIPT_NAME" = "find_rpath.sh" ];then
 echo "$RPATH_OPTION"
elif [ "$SCRIPT_NAME" = "find_rpath.sh" ];then
 echo "$RPATH_OPTION"
else
 echo "$FC"
fi
