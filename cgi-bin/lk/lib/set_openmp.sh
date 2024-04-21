#!/usr/bin/env bash

# Check GCC version
CC=`lib/find_gcc_compiler.sh`
GCC_MAJOR_VERSION=`$CC -dumpversion | cut -f1 -d.` ; 
GCC_MINOR_VERSION=`$CC -dumpversion | cut -f2 -d.` ;

GONOGO=0 # 0 - no-go; 1 - go

if [ $GCC_MAJOR_VERSION -gt 4 ];then
 GONOGO=1
fi

# if >gcc-4.3  
if [ $GCC_MAJOR_VERSION -ge 4 ];then 
 if [ $GCC_MINOR_VERSION -ge 3 ];then
  GONOGO=1
 fi 
fi

if [ $GONOGO -eq 1 ];then
 # Try to use -fopenmp
 echo "
/*
  OpenMP example program Hello World.
  The master thread forks a parallel region.
  All threads in the team obtain their thread number and print it.
  Only the master thread prints the total number of threads.
  Compile with: gcc -O3 -fopenmp omp_hello.c -o omp_hello
*/

#include <omp.h>
#include <stdio.h>
#include <stdlib.h>

int main (int argc, char *argv[]) {
  
  int nthreads, tid;

  /* Fork a team of threads giving them their own copies of variables */
#pragma omp parallel private(nthreads, tid)
  {
    /* Get thread number */
    tid = omp_get_thread_num();
    fprintf(stderr,\"Hello World from thread = %d\n\", tid);
    
    /* Only master thread does this */
    if (tid == 0) {
      nthreads = omp_get_num_threads();
      fprintf(stderr,\"Number of threads = %d\n\", nthreads);
    }
  }  /* All threads join master thread and disband */
  exit(0);
}
" > test.c
 $CC -march=native -fopenmp -o test test.c &>/dev/null
 if [ $? -eq 0 ];then
  echo -n "-fopenmp -DVAST_ENABLE_OPENMP "
 fi
 rm -f test test.c
fi

echo -en "\n"
