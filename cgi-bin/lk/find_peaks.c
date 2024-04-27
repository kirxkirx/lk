#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

int main(int argc, char **argv){
 FILE *periodogramfile;
 
 long i,N;
 
 double *freq;
 double *theta;
 char str[1024];
 
 double minfreq,maxfreq;

 int n_fork=8; // number of parallel threads
 int i_fork=0; // counter for fork
 pid_t pid;
 int pid_status;
 int *child_pids;
   
 // check if we have enough argumets
 if( argc<2 ){
  fprintf(stderr,"Usage: %s lk.periodogram\n",argv[0]);
  return 1;
 }

 child_pids=malloc(n_fork*sizeof(int));
 if ( NULL == child_pids ) {
  fprintf(stderr, "ERROR in compute_phases(): child_pids is NULL\n");
  exit( EXIT_FAILURE );
 }
 
 // read the periodogram file
 periodogramfile=fopen(argv[1],"r");
 if( NULL==periodogramfile ){
  fprintf(stderr,"ERROR: cannot open file %s \n",argv[1]);
  return 1;
 }
 // get number of lines
 N=0;while( NULL!=fgets( str, 1024, periodogramfile) )N++;
 // allocate memory
 freq=malloc(N*sizeof(double));
 theta=malloc(N*sizeof(double));
 // go back to the beginning of the file
 fseek(periodogramfile,0,SEEK_SET);
 // determine file format 2 or 3 columns
 fgets( str, 1024, periodogramfile);
 if( 3==sscanf( str,"%lf %lf %lf",&freq[0],&freq[0],&freq[0])){
  // go back to the beginning of the file
  fseek(periodogramfile,0,SEEK_SET);
  // read the data
  i=0;while(-1<fscanf(periodogramfile,"%lf %lf %lf",&freq[i],&theta[i],&minfreq))i++;
 }
 else{
  // go back to the beginning of the file
  fseek(periodogramfile,0,SEEK_SET);
  // read the data
  i=0;while(-1<fscanf(periodogramfile,"%lf %lf",&freq[i],&theta[i]))i++; 
 }
 fclose(periodogramfile);
 
 // find range of values
 minfreq=maxfreq=freq[0];
 for(i=N;i--;){
  if( minfreq>freq[i] )minfreq=freq[i];
  if( maxfreq<freq[i] )maxfreq=freq[i];
 }
 double freqrange=maxfreq-minfreq;
 
 double windowminfreq,windowmaxfreq,freqthetamax,thetamax;
 double windowsize=0.025*freqrange;
 
 windowminfreq=minfreq;
 while( windowminfreq<maxfreq ){
  thetamax=0.0;
  freqthetamax=0.0;
  windowmaxfreq=windowminfreq+windowsize;
  if( windowmaxfreq>maxfreq )windowmaxfreq=maxfreq;
  i_fork++;
  pid=fork();
  if( pid==0 ){
   for(i=N;i--;){
    // are we inside the window?
    if( freq[i]<windowminfreq ){
     continue;
    }
    if( freq[i]>windowmaxfreq ){
     continue;
    }
    // we are inside
    if( thetamax<theta[i] ){
     thetamax=theta[i];
     freqthetamax=freq[i];
    }
   }
   fprintf(stdout,"%lf %.8lf\n",freqthetamax,thetamax);
   return 0;
  }
  else{
   // if parent
   child_pids[i_fork-1]=pid;
   if( i_fork>=n_fork ){
    for(;i_fork--;){
     pid=child_pids[i_fork];
     waitpid(pid,&pid_status,0);
    }
    i_fork=0;
   }
  }
  windowminfreq=windowmaxfreq;
 }

 free(child_pids);
 
 free(freq);
 free(theta);
 
 return 0;
}
