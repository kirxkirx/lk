all: clean phase_lc lk_compute_periodogram formater_out_wfk find_point colstat print_lightcurve_stats deeming_compute_periodogram find_peaks hjd hms2deg clean_objects
#all: clean phase_lc lk_compute_periodogram formater_out_wfk find_point colstat print_lightcurve_stats deeming_compute_periodogram find_peaks hjd hms2deg check_tai_utc_updates clean_objects

########## Compiler flags
# debug valgrind
#OPTFLAGS = -g -Wall -Warray-bounds -Wextra -fno-omit-frame-pointer -fstack-protector-all -O0 # for debugging with valgrind
#OPTFLAGS_SECURE = $(OPTFLAGS)
# debug asan
#OPTFLAGS = -g -Wall -Wno-comment  -fsanitize=address,undefined -fsanitize-address-use-after-scope -O0
#OPTFLAGS_SECURE = $(OPTFLAGS)
# production
OPTFLAGS = -O3 -w `lib/set_good_march.sh` -ffast-math
OPTFLAGS_SECURE = -O2 -w `lib/set_good_march.sh` -ffast-math -fPIE -fstack-protector-all -D_FORTIFY_SOURCE=2
#
USE_SINCOS_OPITION := $(shell lib/check_sincos.sh)
USE_OMP_OPTIONS := $(shell lib/set_openmp.sh)
CC := $(shell lib/find_gcc_compiler.sh)
##########

#
# Main algorithm
#
lk_compute_periodogram: deeming_compute_periodogram
	ln -s  deeming_compute_periodogram lk_compute_periodogram ; ln -s deeming_compute_periodogram compute_periodogram_allmethods
deeming_compute_periodogram.o: deeming_compute_periodogram.c
	$(CC) $(OPTFLAGS) $(USE_OMP_OPTIONS) -DVAST_WEB_LK -c -o deeming_compute_periodogram.o deeming_compute_periodogram.c #-lgsl -lgslcblas -lm
deeming_compute_periodogram: deeming_compute_periodogram.o
	$(CC) $(OPTFLAGS) $(USE_OMP_OPTIONS) $(USE_SINCOS_OPITION) -o deeming_compute_periodogram deeming_compute_periodogram.o -lgsl -lgslcblas -lm

#
# Stuff directly related to web applications
#
phase_lc: phase_lc.c
	$(CC) $(OPTFLAGS_SECURE) -o phase_lc phase_lc.c -lm
formater_out_wfk: formater_out_wfk.c
	$(CC) $(OPTFLAGS_SECURE) -o formater_out_wfk formater_out_wfk.c
find_point: find_point.c
	$(CC) $(OPTFLAGS_SECURE) -o find_point find_point.c -lm
print_lightcurve_stats: print_lightcurve_stats.c
	$(CC) $(OPTFLAGS_SECURE) -o print_lightcurve_stats print_lightcurve_stats.c
find_peaks: find_peaks.c
	$(CC) $(OPTFLAGS) -o find_peaks find_peaks.c
colstat: colstat.c
	$(CC) $(OPTFLAGS) -o colstat colstat.c -lgsl -lgslcblas -lm

#
# Heliocentric corrections
#
hjd: eph_manager.o hjd.o hjd_N.o novas.o novascon.o nutation.o readeph0.o solsys3.o gettime.o
	$(CC) $(OPTFLAGS_SECURE) -o hjd hjd.o eph_manager.o hjd_N.o novas.o novascon.o nutation.o readeph0.o solsys3.o gettime.o -lm
	ln -s hjd hjd_input_in_UTC
	ln -s hjd hjd_input_in_TT
eph_manager.o: heliocentric_correction/eph_manager.c
	$(CC) $(OPTFLAGS) -c -o eph_manager.o heliocentric_correction/eph_manager.c
hjd.o: heliocentric_correction/hjd.c
	$(CC) $(OPTFLAGS_SECURE) -c -o hjd.o heliocentric_correction/hjd.c
hjd_N.o: heliocentric_correction/hjd_N.c
	$(CC) $(OPTFLAGS_SECURE) -c -o hjd_N.o heliocentric_correction/hjd_N.c
novas.o: heliocentric_correction/novas.c
	$(CC) $(OPTFLAGS) -c -o novas.o heliocentric_correction/novas.c
novascon.o: heliocentric_correction/novascon.c
	$(CC) $(OPTFLAGS) -c -o novascon.o heliocentric_correction/novascon.c
nutation.o: heliocentric_correction/nutation.c
	$(CC) $(OPTFLAGS) -c -o nutation.o heliocentric_correction/nutation.c
readeph0.o: heliocentric_correction/readeph0.o
	$(CC) $(OPTFLAGS) -c -o readeph0.o heliocentric_correction/readeph0.c
solsys3.o: heliocentric_correction/solsys3.c
	$(CC) $(OPTFLAGS) -c -o solsys3.o heliocentric_correction/solsys3.c
gettime.o: heliocentric_correction/gettime.c
	$(CC) $(OPTFLAGS_SECURE) -c -o gettime.o heliocentric_correction/gettime.c

hms2deg: heliocentric_correction/hms2deg.c                                
	$(CC) $(OPTFLAGS_SECURE) -o hms2deg heliocentric_correction/hms2deg.c
        
check_tai_utc_updates: check_for_tai_utc_updates.sh
	./check_for_tai_utc_updates.sh

clean_objects:
	rm -f *.o

clean: 
	rm -f find_peaks find_point formater_out_wfk hjd hjd_input_in_TT hjd_input_in_UTC hms2deg phase_lc print_lightcurve_stats *.o *~ DEADJOE heliocentric_correction/*~
	rm -f lk_compute_periodogram deeming_compute_periodogram compute_periodogram_allmethods colstat

format:
	command -v autopep8 &>/dev/null && autopep8 --in-place --aggressive --aggressive process_lightcurve.py


	
	
	