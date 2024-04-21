#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int main(int argc, char **argv){
 
 FILE *lightcurvefile;
 int i,N;
 double jd,m;
 double jd_min,jd_max,m_min,m_max;
 
// double jd_min_force=-2500000.0;
// double jd_max_force=2500000.0;
 double jd_min_force=-1e32;
 double jd_max_force=1e32;
 
 double jd0;
 
 FILE *outlightcurvefile;
 
 if( argc<1 ){
  fprintf(stderr,"Usage: %s lightcurve.dat\n",argv[0]);
  return 1;
 }
 
 if( argc==4 ){
  if( 0!=strcmp(argv[2],"0") ){
   jd_min_force=atof(argv[2]);
   jd_max_force=atof(argv[3]);
  }
 }
 
 
 lightcurvefile=fopen(argv[1],"r");
 if( NULL==lightcurvefile ){
  fprintf(stderr,"ERROR: cannot open lightcurve file %s\n",argv[1]);
  return 1;
 }
 outlightcurvefile=fopen("lightcurve.tmp","w");
 N=0;
 while(-1<fscanf(lightcurvefile,"%lf %lf",&jd,&m)){
  if( jd<jd_min_force )continue;
  if( jd>jd_max_force )continue;
  if( N==0 ){
   jd_min=jd_max=jd;
   m_min=m_max=m;
  }
  else{
   if( jd_min>jd )jd_min=jd;
   if( jd_max<jd )jd_max=jd;
   if( m_min>m )m_min=m;
   if( m_max<m )m_max=m;
  }
  fprintf(outlightcurvefile,"%.5lf %.5lf\n",jd,m);
  N++;
 }
 fclose(lightcurvefile);
 fclose(outlightcurvefile);
 system("mv lightcurve.tmp lightcurve.dat");
 
 // reusing lightcurvefile, outlightcurvefile
 lightcurvefile=fopen("plot_range.txt","w"); 
 outlightcurvefile=fopen("plot_format.txt","w");
 // select plot range based on amplitude
 if( m_max-m_min > 0.05 ) {
  fprintf(stdout,"The lightcurve contains %d points, the magnitude range is %.2lf - %.2lf, peak-to-peak amplitude %.2lf mag.\n",N,m_min,m_max, (m_max-m_min));
  fprintf(lightcurvefile,"[%.2lf:%.2lf]",m_max+0.05*(m_max-m_min),m_min-0.05*(m_max-m_min));
  fprintf(outlightcurvefile,"%%5.2f");
 } else {
  if( m_max-m_min > 0.005 ) {
   fprintf(stdout,"The lightcurve contains %d points, the magnitude range is %.3lf - %.3lf, peak-to-peak amplitude %.3lf mag.\n",N,m_min,m_max, (m_max-m_min));
   fprintf(lightcurvefile,"[%.3lf:%.3lf]",m_max+0.05*(m_max-m_min),m_min-0.05*(m_max-m_min));
   fprintf(outlightcurvefile,"%%6.3f");
  } else {
   if( m_max-m_min > 0.0005 ) {
    fprintf(stdout,"The lightcurve contains %d points, the magnitude range is %.4lf - %.4lf, peak-to-peak amplitude %.4lf mag.\n",N,m_min,m_max, (m_max-m_min));
    fprintf(lightcurvefile,"[%.4lf:%.4lf]",m_max+0.05*(m_max-m_min),m_min-0.05*(m_max-m_min));
    fprintf(outlightcurvefile,"%%7.4f");   
   } else {
    fprintf(stdout,"The lightcurve contains %d points, the magnitude range is %.5lf - %.5lf, peak-to-peak amplitude %.5lf mag.\n",N,m_min,m_max, (m_max-m_min));
    fprintf(lightcurvefile,"[%.5lf:%.5lf]",m_max+0.05*(m_max-m_min),m_min-0.05*(m_max-m_min));
    fprintf(outlightcurvefile,"%%8.5f");
   }
  }
 }
 //
 fclose(outlightcurvefile);
 fclose(lightcurvefile);

 lightcurvefile=fopen("lightcurve_range.txt","w"); 
 fprintf(lightcurvefile,"%.5lf %.5lf",jd_min,jd_max);
 fclose(lightcurvefile);

 lightcurvefile=fopen("jd0.txt","r");
 fscanf(lightcurvefile,"%lf",&jd0);
 fclose(lightcurvefile);

 jd_max-=jd0;
 jd_min-=jd0;
 lightcurvefile=fopen("lightcurve_plot_range.txt","w"); 
 fprintf(lightcurvefile,"[%.5lf:%.5lf]",jd_min-0.05*(jd_max-jd_min),jd_max+0.05*(jd_max-jd_min));
 fclose(lightcurvefile);

 
 return 0;
}
