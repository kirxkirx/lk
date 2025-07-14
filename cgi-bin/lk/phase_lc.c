#include <stdio.h>
#include <stdlib.h>   
#include <string.h>
#include <math.h>

#include "vast_limits.h" // for MAX_NUMBER_OF_OBSERVATIONS

#define MAX_N_OBS MAX_LIGHTCURVE_POINTS


int find_closest(float x, float y, float *X, float *Y, int N, float new_X1, float new_X2, float new_Y1, float new_Y2){
 float y_to_x_scaling_factor;
 int i;
 float best_dist;
 int best_dist_num;
 
 y_to_x_scaling_factor = fabsf(new_X2-new_X1)/fabsf(new_Y2-new_Y1);
 best_dist_num = 0;
 best_dist = (x-X[0])*(x-X[0])+(y-Y[0])*(y-Y[0])*y_to_x_scaling_factor*y_to_x_scaling_factor; //!!
 for(i=1;i<N;i++){  
  if( (x-X[i])*(x-X[i])+(y-Y[i])*(y-Y[i])*y_to_x_scaling_factor*y_to_x_scaling_factor<best_dist ){
   best_dist=(x-X[i])*(x-X[i])+(y-Y[i])*(y-Y[i])*y_to_x_scaling_factor*y_to_x_scaling_factor;
   best_dist_num=i;
  }
 } 
 return best_dist_num;
}


void get_min_max_double(double *x, int N, double *min, double *max){
 int i;
 (*min) = (*max) = x[0];
 for(i=1;i<N;i++){  
  if( x[i]<(*min) )(*min)=x[i];
  if( x[i]>(*max) )(*max)=x[i];
 }
 return;
}

void get_min_max_float(float *x, int N, float *min, float *max){
 int i;
 (*min) = (*max) = x[0];
 for(i=1;i<N;i++){  
  if( x[i]<(*min) )(*min)=x[i];
  if( x[i]>(*max) )(*max)=x[i];
 }
 return;
}

void make_fake_phases(double *jd, float *phase, float *m, unsigned int N_obs, unsigned int *N_obs_fake){
 unsigned int i;
 FILE *phaserangetypefile;
 int phaserangetype;
 
 phaserangetype = 1;
 
 phaserangetypefile=fopen("phaserange_type.input","r");
 if( NULL!=phaserangetypefile ){
  fscanf(phaserangetypefile,"%d",&phaserangetype);
  fclose(phaserangetypefile);
  if( phaserangetype<1 || phaserangetype>3 )phaserangetype=1; // check range
 }
 
 if( phaserangetype==3 ){
  (*N_obs_fake)=N_obs;
  return;
 }
 
 if( phaserangetype==2 ){
  (*N_obs_fake)=N_obs;
  for(i=0;i<N_obs;i++){
   if( phase[i]>=0.0 ){
    phase[(*N_obs_fake)]=phase[i]+1.0;
    m[(*N_obs_fake)]=m[i];
    jd[(*N_obs_fake)]=jd[i];
    (*N_obs_fake)++;
   }
  }
  return;
 }
 
 (*N_obs_fake)=N_obs;
 for(i=0;i<N_obs;i++){
  if( phase[i]>0.5 ){
   phase[(*N_obs_fake)]=phase[i]-1.0;
   m[(*N_obs_fake)]=m[i];
   jd[(*N_obs_fake)]=jd[i];
   (*N_obs_fake)++;
  }
 }

 return;
}

void compute_phases(double *jd, float *phase, unsigned int N_obs, float f, double jd0){
 unsigned int i;
 double jdi_over_period;

 if ( NULL == jd ) {
  fprintf(stderr, "ERROR in compute_phases(): jd is NULL\n");
  exit( EXIT_FAILURE );
 }
 if ( NULL == phase ) {
  fprintf(stderr, "ERROR in compute_phases(): phase is NULL\n");
  exit( EXIT_FAILURE );
 }
 
 for(i=0;i<N_obs;i++){
  jdi_over_period=(jd[i]-jd0)*(double)f;
  phase[i]=(float)( jdi_over_period-(double)(int)(jdi_over_period) );
  if( phase[i]<0.0 )phase[i]+=1.0;
  //fprintf(stderr,"phase=%f f=%f jd0=%lf jdi_over_period=%lf floor(jdi_over_period)=%lf\n",phase[i],f,jd0,jdi_over_period,trunc(jdi_over_period));
 }
 
 return;
}

int main( int argc, char **argv){
 FILE *lcfile;
 unsigned int N_obs, N_obs_fake;
 double *jd;
 float *phase;
 float *m;
 unsigned int i;
 double JD0;
 float frequency;
 
 if( argc<4 ){
  fprintf(stderr,"Usage: %s lightcurve.dat JD0 period\n",argv[0]);
  return 1;
 }
 
 JD0 = atof(argv[2]);
 frequency = 1.0/atof(argv[3]);

 jd = malloc(MAX_N_OBS*sizeof(double));
 if ( NULL == jd ) {
  fprintf(stderr, "ERROR in main(): jd is NULL\n");
  exit( EXIT_FAILURE );
 }
 phase = malloc(2*MAX_N_OBS*sizeof(float));
 if ( NULL == phase ) {
  fprintf(stderr, "ERROR in main(): phase is NULL\n");
  exit( EXIT_FAILURE );
 }
 m = malloc(2*MAX_N_OBS*sizeof(double)); 
 if ( NULL == m ) {
  fprintf(stderr, "ERROR in main(): m is NULL\n");
  exit( EXIT_FAILURE );
 }

 // read the lightcurve from file
 lcfile=fopen(argv[1],"r");
 if ( NULL == lcfile ) {
  fprintf(stderr, "ERROR in main(): cannot open the input lightcurve file\n");
  exit( EXIT_FAILURE );
 }
 N_obs = 0;
 while(-1<fscanf(lcfile,"%lf %f",&jd[N_obs],&m[N_obs])){
  N_obs++;
  if( N_obs >= MAX_N_OBS ){
   fprintf(stderr, "ERROR: N_obs >= MAX_N_OBS (%d). Input file too large.\n", MAX_N_OBS);
   exit( EXIT_FAILURE );
  }
 }
 fclose(lcfile);

 compute_phases( jd, phase, N_obs, frequency, JD0);
 make_fake_phases( jd, phase, m, N_obs, &N_obs_fake);

 for(i=0;i<N_obs_fake;i++){
  fprintf(stdout,"%+10.7lf %.5lf %.5lf\n", phase[i], m[i], jd[i]);
 }

 free(jd);
 free(phase);
 free(m);

 return 0;
}
