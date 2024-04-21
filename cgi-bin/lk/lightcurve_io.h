// This files provides a common interfice for lightcurve input and output to be used by
// all the VaST routines. The goal is to be able to easily track the exact format in 
// which the lightcurves are stored.

// The following line is just to make sure this file is not included twice in the code
#ifndef VAST_LIGHTCURVE_IO_INCLUDE_FILE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h> // for isalpha()
#include <math.h> // for isnormal()

#include "vast_limits.h"

static inline int write_lightcurve_point( FILE * lc_file_descriptor, double jd, double mag, double mag_err, double x, double y, double app, char * string){
 fprintf( lc_file_descriptor, "%.5lf %8.4lf %.4lf  %10.5lf %10.5lf %4.1lf %s\n", jd, mag, mag_err, x, y, app, string);
 return 0;
}

/*
  read_lightcurve_point() will read one line from a lightcurve file figuring out on its own the lightcurve file format
  
  RETURN VALUES:
  -1 - end of file
   0 - OK, successfully parsed the line
   1 - cannot parse the line, it probably contains comments, jd will also be set to 0.0!
*/

static inline int read_lightcurve_point( FILE * lc_file_descriptor, double * jd, double * mag, double * mag_err, double * x, double * y, double * app, char * string){
 //char * string_for_additional_columns_in_lc_file;

 char * str;

 int str_len; // string length
 int max_index_for_comments_check;
 int i; // counter

 //string_for_additional_columns_in_lc_file=malloc(MAX_STRING_LENGTH_IN_LIGHTCURVE_FILE*sizeof(char));
 //string_for_additional_columns_in_lc_file[MAX_STRING_LENGTH_IN_LIGHTCURVE_FILE-1]='\0'; // just in case
 
 str=malloc(MAX_STRING_LENGTH_IN_LIGHTCURVE_FILE*sizeof(char));
 if( NULL==fgets( str, MAX_STRING_LENGTH_IN_LIGHTCURVE_FILE, lc_file_descriptor) ){free(str);return -1;}
 str[MAX_STRING_LENGTH_IN_LIGHTCURVE_FILE-1]='\0'; // just in case
 
 // A naive attempt to optimize: if the first symbol is a number, assume this is a valid measurement, not a comment
 if( 0==isdigit(str[0]) ){
  // Get string length
  str_len=strlen(str);
  if( str_len<5 ){(*jd)=0.0;return 1;} // assume that a string shorter than 5 bytes will contain no useful lightcurve information
  max_index_for_comments_check=MIN(str_len,10);
  // Check if there are comments in the first 10 bytes of this string
  // If there are, assume this string contains no useful data
  for(i=0;i<max_index_for_comments_check;i++){
   // in most cases we expect the first symbol of the string to be a comment mark
   if( str[i]=='#' ){(*jd)=0.0;return 1;}
   if( str[i]=='%' ){(*jd)=0.0;return 1;}
   if( str[i]=='/' ){(*jd)=0.0;return 1;}
   if( 1==isalpha(str[i]) ){(*jd)=0.0;return 1;}
  }
 }

 //fprintf(stderr,"DEBUG: %s\n",str);
 
 
 // experimental thing, does not work
 //if( 7<sscanf( str, "%lf %lf %lf  %lf %lf %lf %s %[^\t\n]", jd, mag, mag_err, x, y, app, string, string_for_additional_columns_in_lc_file) ){
 if( 7!=sscanf( str, "%lf %lf %lf  %lf %lf %lf %s", jd, mag, mag_err, x, y, app, string) ){
  string[0]='\0';
  (*app)=1.0;
  (*x)=(*y)=0.0;
  if( 3!=sscanf( str, "%lf %lf %lf\n", jd, mag, mag_err) ){
   (*mag_err)=0.02;
   if( 2!=sscanf( str, "%lf %lf\n", jd, mag) ){
    (*jd)=0.0;
    return 1;
   }
  }
 }
 //fprintf(stderr,"DEBUG: %lf string=*%s* string_for_additional_columns_in_lc_file=*%s*\n",(*app),string,string_for_additional_columns_in_lc_file);
 free(str);
 //free(string_for_additional_columns_in_lc_file);

 // Check the input values
 /*
 // I need -std=c99 for isnormal() but specifying it for vast.c causes other problems :(
 if( 0==isnormal( (*jd) ) ){(*jd)=0.0;return 1;}
 if( 0==isnormal( (*mag) ) ){(*jd)=0.0;return 1;}
 if( 0==isnormal( (*mag_err) ) ){(*jd)=0.0;return 1;}
 if( 0==isnormal( (*x) ) ){(*jd)=0.0;return 1;}
 if( 0==isnormal( (*y) ) ){(*jd)=0.0;return 1;}
 if( 0==isnormal( (*app) ) ){(*jd)=0.0;return 1;}
 */
 
 // Check the input date, note that wedon't know if its JD or MJD
 if( (*jd)<EXPECTED_MIN_MJD ){(*jd)=0.0;return 1;}
 if( (*jd)>EXPECTED_MAX_JD ){(*jd)=0.0;return 1;}
 
 // Check the input mag
 if( (*mag)<BRIGHTEST_STARS ){(*jd)=0.0;return 1;}
 // A similar check for the expected faintest stars?

 return 0;
}

static inline int count_points_in_lightcurve_file(char * lightcurvefilename){
 int n;
 FILE * lightcurvefile;
 double jd,mag,merr,x,y,app;
 char string[FILENAME_LENGTH];
 
 lightcurvefile=fopen(lightcurvefilename,"r");
 if( NULL==lightcurvefile ){
  fprintf(stderr,"ERROR: cannot open lightcurve file %s \n",lightcurvefilename);
  return -1;
 }
 
 n=0;
 while(-1<read_lightcurve_point(lightcurvefile,&jd,&mag,&merr,&x,&y,&app,string)){                
  if( jd==0.0 )continue; // if this line could not be parsed, try the next one
  n++;
 }
 
 return n;
}

// The macro below will tell the pre-processor that this header file is already included
#define VAST_LIGHTCURVE_IO_INCLUDE_FILE
#endif
// VAST_LIGHTCURVE_IO_INCLUDE_FILE
