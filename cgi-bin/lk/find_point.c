#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

// set program parameters
#define MAX_POINTS 120000

// set image parameters
#define IMAGE_X   600
#define IMAGE_Y   350
#define CORNER1_X  72
#define CORNER1_Y 308
#define CORNER2_X 578
#define CORNER2_Y  14
#define X_RANGE_PIX (CORNER2_X-CORNER1_X)
#define Y_RANGE_PIX (CORNER1_Y-CORNER2_Y)

// set plot parameters
#define PHASE_MIN -0.55 
#define PHASE_MAX  1.05
#define PHASE_RANGE (PHASE_MAX-PHASE_MIN)

int find_closest(double x, double y, double *X, double *Y,int N, double new_X1, double new_X2, double new_Y1, double new_Y2){
 double y_to_x_scaling_factor=fabsf(new_X2-new_X1)/fabsf(new_Y2-new_Y1);
 int i;
 double best_dist;
 int best_dist_num=0;
 best_dist=(x-X[0])*(x-X[0])+(y-Y[0])*(y-Y[0])*y_to_x_scaling_factor*y_to_x_scaling_factor; //!!
 //for(i=1;i<N;i++){
 for(i=0;i<N;i++){
  if( (x-X[i])*(x-X[i])+(y-Y[i])*(y-Y[i])*y_to_x_scaling_factor*y_to_x_scaling_factor<best_dist ){
   best_dist=(x-X[i])*(x-X[i])+(y-Y[i])*(y-Y[i])*y_to_x_scaling_factor*y_to_x_scaling_factor;
   best_dist_num=i;
  }
 } 
 
 //fprintf(stderr,"targetx=%lf tagety=%lf bestx=%lf besty=%lf\n",x,y,X[best_dist_num],Y[best_dist_num]);
 
 return best_dist_num;
}

int main(int argc, char **argv){
 
 if( argc<3 ){
  fprintf(stderr,"Usage: %s phase_lightcurve.dat clickX clickY\n",argv[0]);
  return 1;
 }
 double clickX=atof(argv[2]);
 double clickY=atof(argv[3]);
 double targetX=clickX-CORNER1_X;
 double targetY=CORNER1_Y-clickY;
// double targetY=CORNER1_Y-clickY; 

 double *jd=malloc(MAX_POINTS*sizeof(double));
 double *phase=malloc(MAX_POINTS*sizeof(double));
 double *m=malloc(MAX_POINTS*sizeof(double));

 FILE *phasefile;
 FILE *phaserangefile;
 
 double phase_min,phase_max,phase_range;
 double max_m,min_m;
 double max_jd,min_jd;
 int N;
 
 FILE *selectedfile;

 phasefile=fopen(argv[1],"r");
 if(NULL==phasefile){
  fprintf(stderr,"ERROR: cannot open file %s for reading\n",argv[1]);
  return 1;
 }
 int i=0;
 if( 0==strcmp(argv[1],"lightcurve.dat") ){
  while(-1<fscanf(phasefile,"%lf %lf",&jd[i],&m[i])){
   phase[i]=jd[i];
   i++;
   if( i>=MAX_POINTS ){
    fprintf(stderr,"ERROR: i>=MAX_POINTS\n");
    return 1;
   }
  }
  N=i;
  max_jd=min_jd=jd[0];
  for(i=0;i<N;i++){
   if( max_jd<jd[i] )max_jd=jd[i];
   if( min_jd>jd[i] )min_jd=jd[i];
  }
  phase_min=min_jd-0.05*(max_jd-min_jd);
  phase_max=max_jd+0.05*(max_jd-min_jd);
  phase_range=phase_max-phase_min;
 }
 else{
  // default values kept only as the reminder to myself
  phase_min=PHASE_MIN;
  phase_max=PHASE_MAX;
  phase_range=PHASE_RANGE;
  // Get the plot range
  phaserangefile=fopen("phase_range.txt","r");
  if(NULL==phaserangefile){
   fprintf(stderr,"ERROR: cannot open file %s for reading\n","phase_range.txt");
   return 1;
  } 
  fscanf(phaserangefile,"[%lf:%lf]",&phase_min,&phase_max);
  fclose(phaserangefile);
  phase_range=phase_max-phase_min;
  // Continue reading phasefile
  while(-1<fscanf(phasefile,"%lf %lf %lf",&phase[i],&m[i],&jd[i])){
   i++;
   if( i>=MAX_POINTS ){
    fprintf(stderr,"ERROR: i>=MAX_POINTS\n");
    return 1;
   }
  }
 }
 fclose(phasefile);
 N=i;

 // Get the plot range
 phasefile=fopen("plot_range.txt","r");
 if(NULL==phasefile){
  fprintf(stderr,"ERROR: cannot open file %s for reading\n","plot_range.txt");
  return 1;
 } 
 //fscanf(phasefile,"[%lf:%lf]",&min_m,&max_m);
 fscanf(phasefile,"[%lf:%lf]",&max_m,&min_m);
 fclose(phasefile);

 
 double m_range=max_m-min_m;

 double x_pix_to_phase=phase_range/X_RANGE_PIX;
 double y_pix_to_m=m_range/Y_RANGE_PIX;
 
 double target_phase=phase_min+targetX*x_pix_to_phase;
 double target_m=max_m-targetY*y_pix_to_m;
 
 int targetN;
 targetN=find_closest( target_phase, target_m, phase, m, N, phase_min, phase_max, min_m, max_m);
 double targetJD=jd[targetN];
 
 int fnumber; // lightcurve file number: 0 is lightcurve.dat, N is phase_lc_N.dat
 char filename[256]; // lightcurve file name that will be dynamically generated
 for(fnumber=0;fnumber<21;fnumber++){
  // Read lightcurve
  if( fnumber==0 )
   sprintf(filename,"lightcurve.dat");
  else
   sprintf(filename,"phase_lc_%d.dat",fnumber);
  phasefile=fopen(filename,"r");
  if(NULL==phasefile){
   fprintf(stderr,"ERROR: cannot open file %s for reading\n",filename);
   return 1;
  }
  i=0;
  if( fnumber==0 )
   while(-1<fscanf(phasefile,"%lf %lf",&jd[i],&m[i])){
    i++;
    if( i>=MAX_POINTS ){
     fprintf(stderr,"ERROR: i>=MAX_POINTS\n");
     return 1;
    }
   }
  else
   while(-1<fscanf(phasefile,"%lf %lf %lf",&phase[i],&m[i],&jd[i])){
    i++;
    if( i>=MAX_POINTS ){
     fprintf(stderr,"ERROR: i>=MAX_POINTS\n");
     return 1;
    }
   }
  fclose(phasefile);
  N=i;
  
  // Write edited lightcurve
  phasefile=fopen(filename,"w");
  if(NULL==phasefile){
   fprintf(stderr,"ERROR: cannot open file %s for writing\n",filename);
   return 1;
  }
  

  strcat(filename,".selected");

  selectedfile=fopen(filename,"a");
  if(NULL==selectedfile){
   fprintf(stderr,"ERROR: cannot open file _%s_ for writing\n",filename);
   return 1;
  }
  
  for(i=0;i<N;i++)
   if( fabs(jd[i]-targetJD)>0.00001 ){
    if( fnumber==0 )
     fprintf(phasefile,"%.5lf %.5lf\n", jd[i], m[i]);
    else
     fprintf(phasefile,"%.5lf %.5lf %.5lf\n", phase[i], m[i], jd[i]);
   }
   else{
    if( fnumber==0 )
     fprintf(selectedfile,"%.5lf %+.5lf\n", jd[i], m[i]);
    else
     fprintf(selectedfile,"%+10.7lf %.5lf %.5lf\n", phase[i], m[i], jd[i]);
   }
  fclose(phasefile);
  fclose(selectedfile);
 }

 fprintf(stdout,"%lf %lf   %d %lf %lf\n",target_phase,target_m,N,phase[targetN],jd[targetN]);
 
 free(m);
 free(phase);
 free(jd);

 return 0;
}
