#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

#define MAX_NUMBER_OF_LEAP_SECONDS 100 /* Maximum number of lines in heliocentric_correction/tai-utc.dat file */


double convert_jdUT_to_jdTT(double jdUT, int *timesys){
 FILE *tai_utc_dat;
 double jdTT;
 double *jd_leap_second;
 jd_leap_second=malloc(MAX_NUMBER_OF_LEAP_SECONDS*sizeof(double));
 if( jd_leap_second==NULL ){fprintf(stderr,"ERROR: in convert_jdUT_to_jdTT() can't allocate memory for jd_leap_second\n");exit(1);}
 double *TAI_minus_UTC;
 TAI_minus_UTC=malloc(MAX_NUMBER_OF_LEAP_SECONDS*sizeof(double));
 if( TAI_minus_UTC==NULL ){fprintf(stderr,"ERROR: in convert_jdUT_to_jdTT() can't allocate memory for TAI_minus_UTC\n");exit(1);}
 double tai_utc;
 char str1[256], str2[256];
 int i;
 int n_leap_sec=0;
 
 double MJD=jdUT-2400000.5; // for leap second calculation before 1972 JAN  1
 double *MJD0;
 MJD0=malloc(MAX_NUMBER_OF_LEAP_SECONDS*sizeof(double));
 if( MJD0==NULL ){fprintf(stderr,"ERROR: in convert_jdUT_to_jdTT() can't allocate memory for MJD0\n");exit(1);}
 double *leap_second_rate;
 leap_second_rate=malloc(MAX_NUMBER_OF_LEAP_SECONDS*sizeof(double));
 if( leap_second_rate==NULL ){fprintf(stderr,"ERROR: in convert_jdUT_to_jdTT() can't allocate memory for leap_second_rate\n");exit(1);}
 
 /* 
   Read the file with leap seconds lib/tai-utc.dat
   up-to-date version of this file is available at 
   http://maia.usno.navy.mil/ser7/tai-utc.dat
 */
 tai_utc_dat=fopen("heliocentric_correction/tai-utc.dat","r");
 if( NULL==tai_utc_dat ){
  fprintf(stderr,"ERROR: can't open file heliocentric_correction/tai-utc.dat\n");
  exit(1);
 }
 while( NULL!=fgets(str1, 256, tai_utc_dat) ){
  for(i=17;i<26;i++)str2[i-17]=str1[i];
  str2[i-17]='\0';
  jd_leap_second[n_leap_sec]=atof(str2);
  for(i=37;i<48;i++)str2[i-37]=str1[i];
  str2[i-37]='\0';
  TAI_minus_UTC[n_leap_sec]=atof(str2);
  for(i=60;i<66;i++)str2[i-60]=str1[i];
  str2[i-60]='\0';
  MJD0[n_leap_sec]=atof(str2);
  for(i=70;i<79;i++)str2[i-70]=str1[i];
  str2[i-70]='\0';
  leap_second_rate[n_leap_sec]=atof(str2);
  n_leap_sec++;
 }
 fclose(tai_utc_dat);

 

 if( jdUT<jd_leap_second[0] )fprintf(stderr,"WARNING: TT is not defined before %.5lf\n",jd_leap_second[0]);

 tai_utc=TAI_minus_UTC[0];
 for(i=1;i<n_leap_sec;i++)
  if( jdUT>=jd_leap_second[i] ){
   tai_utc= TAI_minus_UTC[i] + (MJD - MJD0[i]) * leap_second_rate[i];  //tai_utc=TAI_minus_UTC[i];
   //fprintf(stderr,"DEBUG: %02d TT-UTC=%.3lf \n",i,(32.184+tai_utc) );
  }
  
 jdTT=jdUT+(32.184+tai_utc)/86400; // TT = TAI + 32.184
                                   // TAI = UTC + leap_seconds

 //fprintf(stderr,"DEBUG: TT-UTC=%.3lf \n",(32.184+tai_utc) );

 /* Set marker that time system was changed */ 
 (*timesys)=2; // TT

 free(jd_leap_second);
 free(TAI_minus_UTC);
 free(MJD0);
 free(leap_second_rate);

 return jdTT;
}
