// This file contains VaST setings that are not expected to change during runtime

// Please note that the correct name of this file is "vast_limits.h", "limits.h" is a symlink kept for compatibility.
// The problem with the old name is that it was the same as one of the standard C include files.

// The following line is just to make sure this file is not included twice in the code
#ifndef VAST_LIMITS_INCLUDE_FILE

//////// Settings that control VaST start here ////////

#define N_FORK 5 // Default number of SExtractor threads running in parallel
                 // this option is used only if the number of CPU cores cannot be determined at runtime

/* Memory settings */
#define MAX_NUMBER_OF_STARS 300000
#define MAX_NUMBER_OF_OBSERVATIONS 1000000 // per star
#define MAX_MEASUREMENTS_IN_RAM 1200000 /* Max. number of measurements to be stored in memory */
#define FILENAME_LENGTH 1024 /* Max. image filename length */
#define OUTFILENAME_LENGTH 128 /* Max. out filename length */
#define MAX_STRING_LENGTH_IN_LIGHTCURVE_FILE 512+FILENAME_LENGTH // assuming each string in any lightcurve file is not longer than this
#define MAX_STRING_LENGTH_IN_SEXTARCTOR_CAT 512 // Maximum string langth in image00001.cat
#define MAX_STRING_LENGTH_IN_VAST_LIGHTCURVE_STATISTICS_LOG 512 // Maximum string langth in vast_lightcurve_statistics.log

#define MAX_RAM_USAGE 0.7 /* Try not to store in RAM more than MAX_RAM_USAGE*RAM_size */
#define MAX_NUMBER_OF_BAD_REGIONS_ON_CCD 64 /* Which may be described in bad_region.lst */
#define MAX_NUMBER_OF_LEAP_SECONDS 100 /* Maximum number of lines in lib/tai-utc.dat file */

/* Star detection */
#define FRAME_EDGE_INDENT_PIXELS 10.0  // Don't take into account stars closer than FRAME_EDGE_INDENT_PIXELS pixels to a frame edge. 
                                       // This constant was called OTSTUP in previous versions of VaST.
#define MIN_NUMBER_OF_STARS_ON_FRAME 5 // Frames with less than MIN_NUMBER_OF_STARS_ON_FRAME stars detected will not be used
#define AUTO_SIGMA_POPADANIYA_COEF 0.6 // Important for star matchning! Stars are matched if their coordinates on two images coincide within AUTO_SIGMA_POPADANIYA_COEF*aperture if -s -m or -w switch is not set. 
#define HARD_MIN_NUMBER_OF_POINTS 2    // Potential transients with less than HARD_MIN_NUMBER_OF_POINTS will be discarded!
                                       // Parameter used in  src/remove_lightcurves_with_small_number_of_points.c 
#define SOFT_MIN_NUMBER_OF_POINTS 40   // Recommend a user to use at least SOFT_MIN_NUMBER_OF_POINTS images in the series

///////////////////// !!! /////////////////////
// If defined create_data WILL NOT COMPUTE VARIABILITY INDEXES for the lightcurves having
// less than MIN(SOFT_MIN_NUMBER_OF_POINTS,(int)(0.5*number_of_measured_images_from_vast_summary_log))
// points! You may miss some transient objects that appear only temporary if this option is enabled,
// but dropping lightcurves with small number of points dramatically reduces the number of false candidates.
#define DROP_LIGHTCURVS_WITH_SMALL_NUMBER_OF_POINS_FROM_ALL_PLOTS
///////////////////////////////////////////////

#define FAINTEST_STARS 0.0             // Instrumental (with respect to the background) magnitude of faintest stars.
                                       // Parameter used in src/data_parser.c 
#define FAINTEST_STARS_PHOTO -1.0 /* Same as FAINTEST_STARS but for photographic plate reduction mode.
                                     Parameter used in src/data_parser.c */
#define BRIGHTEST_STARS -30.0 /* Instrumental (with respect to the background) magnitude of brightest stars. 
                                 Parameter used in src/data_parser.c */
#define MAX_MAG_ERROR 10.0 /* Discard observations with the lightcurve scatter greater than MAX_MAG_ERROR. Parameter used in src/data_parser.c */
//#define MIN_SNR  5.0     /* Discard stars detected with signal-to-noise ratio < MIN_SNR */
#define MIN_SNR  3.0

// ATTENTION! 
// If the stars are really small use a different value of FWHM_MIN=0.0 
// to loose the restrictions on the star image shape!
// The value of FWHM_MIN for small stars are now used by default.
// If star images on your CCD frames have normal size (span many pixels), it is strongly
// recommended to use FWHM_MIN 0.85 (or some similar value).
//
//#define FWHM_MIN 0.85      /* pix, only stars with FWHM > FWHM_MIN (pix) will be processed   */
//
//#define FWHM_MIN 0.0         // for small stars
#define FWHM_MIN 0.1
//

#define SATURATION_LIMIT_INDENT 0.1 // guessed_saturation_limit=maxval-SATURATION_LIMIT_INDENT*maxval;

#define FRACTION_OF_ZERO_PIXEL_TO_USE_FLAG_IMG 0.01 // if the image has more than FRACTION_OF_ZERO_PIXEL_TO_USE_FLAG_IMG*total_number_of_pixels
                                                    // pixels with zero values - use the flag image to flag-out these bad regions
                                                    // and avoid numerous supurious detections arond their edges
#define N_POINTS_PSF_FIT_QUALITY_FILTER 7

// Only image pixels with values between MIN_PIX_VALUE and MAX_PIX_VALUE are considered good ones
#define MIN_PIX_VALUE -100000
#define MAX_PIX_VALUE  100000

#define FLAG_N_PIXELS_AROUND_BAD_ONE 2 // that many pixels will be flagged around each bad pixel (if flag image is to be used)

#define MAX_SEXTRACTOR_FLAG 1 // Maximum star flag value set by sextractor acceptable for VaST
                              // You may override this at runtime with '-x N' parameter, for example:
                              // ./vast -x3 ../sample_data/*fit
                              // Will accept all stars having flag less or equal to 3
                              
                              // A reminder:
                              // 1     The object has neighbors, bright and close enough to 
                              //       significantly bias the photometry, or bad pixels 
                              //       (more than 10% of the integrated area affected).
                              //            
                              // 2     The object was originally blended with another one.
                              //            
                              // 4     At least one pixel of the object is saturated 
                              //       (or very close to).
                              //
                              // And trust me, you don't want to consider objects with flags more than 4.
                              //
                                                

/* Star matching */
#define MAX_MATCH_TRIALS 5 /* discard image if it was still not matched after MAX_MATCH_TRIALS attempts */
//#define MIN_FRACTION_OF_MATCHED_STARS 0.05
#define MIN_FRACTION_OF_MATCHED_STARS 0.41 /* discard image if <MIN_FRACTION_OF_MATCHED_STARS*number_stars_on_reference_image were matched */
                                           /* (should always be <0.5 !!!) discard image if <MIN_FRACTION_OF_MATCHED_STARS*number_stars_on_reference_image were matched */
#define MIN_FRACTION_OF_MATCHED_STARS_STOP_ATTEMPTS 0.1 /* Do not attempt to match images if less than MIN_FRACTION_OF_MATCHED_STARS_STOP_ATTEMPTS were matched after a few iterations */
                                                        /* because something is evidently wrong with that image. */
#define MATCH_MIN_NUMBER_OF_REFERENCE_STARS 100
#define MATCH_MIN_NUMBER_OF_TRIANGLES 20*MATCH_MIN_NUMBER_OF_REFERENCE_STARS
#define MATCH_REFERENCE_STARS_NUMBER_STEP 500 // Search for an optimal number of reference stars between MATCH_MIN_NUMBER_OF_REFERENCE_STARS and
                                              // MATCH_MAX_NUMBER_OF_REFERENCE_STARS with step MATCH_REFERENCE_STARS_NUMBER_STEP 
#define MATCH_MAX_NUMBER_OF_REFERENCE_STARS 3000 // 1200 //700 /* Give up trying to match frame if it was not matched with MATCH_MAX_NUMBER_OF_REFERENCE_STARS stars */
#define MATCH_MAX_NUMBER_OF_TRIANGLES 20*MATCH_MAX_NUMBER_OF_REFERENCE_STARS // 3 triangles paer star in the current algorithm
#define MATCH_MAX_NUMBER_OF_STARS_FOR_SMALL_TRIANGLES 700 // The starfield is divided in triangles using two statagies:
                                                          // one produces largi triangles from stars of close brightness while
                                                          // the second produces small triangles from closely separated stars.
                                                          // The search for closest neighbour becomes very computationally expansive as the number of stars increases.
                                                          // So, separation for small triangles will not be performed if the number of reference stars is > MATCH_MAX_NUMBER_OF_STARS_FOR_SMALL_TRIANGLES
#define MIN_SUCCESS_MATCH_ON_RETRY 5 /* if more than MIN_SUCCESS_MATCH_ON_RETRY images were successfully matched after increasing the number of reference stars
                                        - change the number of reference stars */
#define MIN_N_IMAGES_USED_TO_DETERMINE_STAR_COORDINATES 15  /* Use median position of a star after MIN_N_IMAGES_USED_TO_DETERMINE_STAR_COORDINATES
 measurements of its position were collected (star's position on the reference frame is used before). */
#define MAX_N_IMAGES_USED_TO_DETERMINE_STAR_COORDINATES 200 /* Only the first MAX_N_IMAGES_USED_TO_DETERMINE_STAR_COORDINATES
 will be used to determine average star positions in the reference image coordinate system (needed for star matching).
 This is done to save memory, because otherwise all the coordinates needs to be kept in memory all the time... */
#define POSITION_ACCURACY_AS_A_FRACTION_OF_APERTURE 0.1 /* Assume the position of a star may be measured with accuracy of POSITION_ACCURACY_AS_A_FRACTION_OF_APERTURE */
#define MAX_SCALE_FACTOR 0.05 // Assume that images have the same scale to the accuracy of MAX_SCALE_FACTOR - important for star matching.
#define ONE_PLUS_MAX_SCALE_FACTOR_SIX (1.0+MAX_SCALE_FACTOR)*(1.0+MAX_SCALE_FACTOR)*(1.0+MAX_SCALE_FACTOR)*(1.0+MAX_SCALE_FACTOR)*(1.0+MAX_SCALE_FACTOR)*(1.0+MAX_SCALE_FACTOR)

/* Magnitude calibration */
#define MAX_MAG_FOR_med_CALIBRATION -3.0 /* Do not use too faint stars for magnitude calibration. */
#define CONST 6 /* measurement APERTURE=median_A*CONST where median_A - typical major axis of star images on the current frame (pix.) */
#define MAX_AP_DIFF 5.5 /* Maximal difference in seeing during one night (pix.) */
#define MAX_DIFF_POLY_MAG_CALIBRATION 0.3 //0.5 
/* stars which deviate more than MAX_DIFF_POLY_MAG_CALIBRATION from the fit will
                                             be discarded from the magnitude calibration procedure */
#define MIN_NUMBER_STARS_POLY_MAG_CALIBR 40 /* magnitude calibration with parabola will not be performed 
                                             if there are less than MIN_NUMBER_STARS_POLY_MAG_CALIBR stars */                                             
#define MAX_INSTR_MAG_DIFF 99.0 /* Do not use stars with instrumental mag difference >MAX_INSTR_MAG_DIFF for magnitude calibration 
                                   (turn out to be not really useful parameter) */
#define MIN_NUMBER_OF_STARS_FOR_CCD_POSITION_DEPENDENT_MAGNITUDE_CORRECTION 10000 // If the reference image has >MIN_NUMBER_OF_STARS_FOR_CCD_POSITION_DEPENDENT_MAGNITUDE_CORRECTION
// on it, a linear CCD-position-dependent magnitude correctin will be computed.
// This can be overriden from the command line -J or -j
#define MAX_LIN_CORR_MAG 0.5 // Maximum CCD-position-dependent magnitude correctin/
// If the estimated correction is larger at frame's corners, the magnitude calibration will be failed


/* Transient search (!!!EXPERIMENTAL!!!) */
#define TRANSIENT_MIN_TIMESCALE_DAYS 1.0 // expect transients apearing on timescale > TRANSIENT_MIN_TIMESCALE_DAYS
#define MAG_TRANSIENT_ABOVE_THE_REFERENCE_FRAME_LIMIT 1.3 // Transient candidates should be at least MAG_TRANSIENT_ABOVE_THE_REFERENCE_FRAME_LIMIT mag
                                                          // above the detection limit on the reference frame.
// #define FLARE_MAG 1.0
#define FLARE_MAG 0.9 // Objects which are found to be FLARE_MAG magnitudes brighter on the current image than on the reference image
                      // will be also listed as transient candidates
#define MIN_DISTANCE_BETWEEN_STARS_IN_APERTURE_DIAMS 0.8 //0.7


/* src/fit_mag_calib.c */
#define MAX_NUMBER_OF_STARS_MAG_CALIBR MAX_NUMBER_OF_STARS

/* src/m_sigma_bin.c */
#define M_SIGMA_BIN_SIZE_M 0.35
#define M_SIGMA_BIN_DROP 1 
#define M_SIGMA_BIN_MAG_OTSTUP 0.1
#define M_SIGMA_BIN_MAG_SIGMA_DETECT 0.7 /* Increase this parameter
                                            if you want more conservative candidate selection */

/* src/stetson_variability_indexes.c */
 #define WS_BINNING_DAYS 1.0 // for the plot
//#define WS_BINNING_DAYS 2.0 // Max time difference in days between data points that can form a pair for Stetson's indexes.
                            // Stetson's indexes  are sensitive to variability on timescales >> WS_BINNING_DAYS
#define MAX_PAIR_DIFF_SIGMA_FOR_JKL_MAG_CLIP 5.0 // Do not form pairs from points that differ by more than DEFAULT_MAX_PAIR_DIFF_SIGMA*error mags

#define N3_SIGMA 3.0 // deviation of N3_SIGMA of three consequetive lightcurve points from the mean is considered significant

// Parameters for detecting Excursions
#define EXCURSIONS_GAP_BETWEEN_SCANS_DAYS 5.0 // Form scans from points that are not more than EXCURSIONS_GAP_BETWEEN_SCANS_DAYS apart to detect excursions 
                                              // 'Excursions' are the significant changes of brightness from scan to scan.

/* src/find_candidates.c */
#define DEFAULT_FRAME_SIZE_X 30000
#define DEFAULT_FRAME_SIZE_Y 30000

/* periodFilter/periodS2.c */
#define ANOVA_MIN_PERIOD 0.05  // days
#define ANOVA_MAX_PERIOD 30.0  // days

/* BLS/bls.c */
#define BLS_SIGMA 0.05  // assume all points have the same sigma
#define BLS_CUT 7.3 // consider as real 
                    // periods with snr>BLS_CUT
#define BLS_MIN_FREQ  0.2
#define BLS_MAX_FREQ  3.0
#define BLS_FREQ_STEP 0.00002
#define BLS_DI_MAX    24 // max. eclipse duration
#define BLS_DI_MIN     8 // min. eclipse duration
                    
/* src/vast_math.c (stat) */
#define STAT_NDROP 0 // for the simulation!!!!
// This now affects only the legacy sigma plot (2nd column in data.m_sigma)
//#define STAT_NDROP 5 // 10 // Drop STAT_NDROP brightest and STAT_NDROP faintest 
                      // points before calculating sigma
// Apply lightcurve filtering before computing variability indexes only to the lightcurve
// having at least STAT_MIN_NUMBER_OF_POINTS_FOR_NDROP points
#define STAT_MIN_NUMBER_OF_POINTS_FOR_NDROP SOFT_MIN_NUMBER_OF_POINTS

/* src/pgfv/pgfv.c */
#define PGFV_CUTS_PERCENT 99.5 //99.75 //95.0 //99.5

/* src/match_eater.c */
#define MIN_MATCH_DISTANCE_PIX 600
#define MAX_MATCH_DISTANCE_PIX 10*MIN_MATCH_DISTANCE_PIX

/* src/fix_photo_log.c */
#define MAX_LOG_STR_LENGTH 1024

/* src/sysrem.c */
#define NUMBER_OF_Ai_Ci_ITERATIONS 1000
#define Ai_Ci_DIFFERENCE_TO_STOP_ITERATIONS 0.00001

/* src/new_lightcurve_sigma_filter.c */
#define LIGHT_CURVE_FILTER_SIGMA 7.0

/* src/remove_points_with_large_errors.c */
#define LIGHT_CURVE_ERROR_FILTER_SIGMA 5.0

/* src/hjd.c */
#define EXPECTED_MIN_JD 2400000.0
#define EXPECTED_MAX_JD 2500000.0
// EXPECTED_MIN_JD and EXPECTED_MAX_JD are useful for checking if an input number actually looks like a correct JD
// same for EXPECTED_MIN_MJD and EXPECTED_MAX_MJD
//#define EXPECTED_MIN_MJD 15020.0 // CE  1900 January  1 00:00:00.0 UT
#define EXPECTED_MIN_MJD 0.0 // no, can't use #define EXPECTED_MIN_MJD 15020.0 since in practice users love to truncate JD in really unpredictable ways
#define EXPECTED_MAX_MJD 124593.0 // CE  2200 January  1 00:00:00.0 UT

#define SHORTEST_EXPOSURE_SEC 0.0 // the shortest exposure time in seconds considered as valid by VaST
#define LONGEST_EXPOSURE_SEC 86400.0 // the longest exposure time in seconds considered as valid by VaST

/* src/photocurve.c */
#define N_POINTS_FOR_SPLINE_INTERPOLATION_FOR_INVERSE_PHOTOCURVE 12

// Warn the user that match with external catalog probably dind't go well
#define MIN_NUMBER_OF_STARS_FOR_UCAC4_MATCH 20


//////// Settings that control VaST end here ////////

/* Auxiliary definitions */
#define MAX(a, b) (((a)>(b)) ? (a) : (b))
#define MIN(a, b) (((a)<(b)) ? (a) : (b))

//////////////////////////////////////////////////
// Enable debug file output and many debug messages on the terminal.
// Should not be set for pruduction.
//#define DEBUGFILES

#define DEFAULT_PHOTOMETRY_ERROR_MAG 0.01


// The macro below will tell the pre-processor that limits.h is already included
#define VAST_LIMITS_INCLUDE_FILE

#endif
// VAST_LIMITS_INCLUDE_FILE
