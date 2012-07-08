#!/bin/bash

# Firebot
# FDS automatIc veRification and validation tEst bot
# Kristopher Overholt
# 6/22/2012

#  ===================
#  = Input variables =
#  ===================

mailTo="kristopher.overholt@nist.gov"
SVNROOT="/home/firebot/FDS-SMV"
FIREBOT_DIR="/home/firebot/firebot"
SVN_REVISION=$1

#  =========================
#  = External dependencies =
#  =========================
#
#   This script expects the following dependencies to be in place:
#   
#   cfast (for Stage 5 - Run_SMV_Cases.sh):
#      ~/cfast/CFAST/intel_linux_64/cfast6_linux_64
#
#   SMV (for Stage 6b - Make_FDS_Pictures.sh)
#      ~/FDS/FDS6/bin/smokeview_linux_64
#

#  ====================
#  = End user warning =
#  ====================

# Warn if running as user other than firebot
if [[ `whoami` == "firebot" ]];
   then
      # Continue along
      :
   else
      echo "Warning: You are running the Firebot script as an end user."
      echo "This script can modify and erase your repository."
      echo "If you wish to continue, edit the script and remove this warning."
      echo "Terminating script."
      exit
fi

#  ===========================
#  = Exit if already running =
#  ===========================
# Abort script if another instance is running
# This command should return a "2" (from within this script) if only one script is running
if [[ `pgrep -f firebot.sh | wc -l` -gt 2 ]];
   then
      echo "Warning: The Firebot verification script is already running."
      echo "Terminating this script."
      exit
   else
      # Continue along
      :
fi

#  ====================
#  = Sample functions =
#  ====================
 
# sample_are_there_changes()
# {
#    svn up > $FIREBOT_DIR/tmpsvnup

#    grep "^U" $FIREBOT_DIR/tmpsvnup &> /dev/null
#    if [[ $? == 0 ]]
#    then
#       return 1
#    fi

#    grep "^A" $FIREBOT_DIR/tmpsvnup &> /dev/null
#    if [[ $? == 0 ]]
#    then
#      return 1
#    fi

#    grep "^D" $FIREBOT_DIR/tmpsvnup &> /dev/null
#    if [[ $? == 0 ]]
#    then
#       return 1
#    fi

#    grep "^G" $FIREBOT_DIR/tmpsvnup &> /dev/null
#    if [[ $? == 0 ]]
#    then
#       return 1
#    fi
 
#    return 0
# }

#  ============================
#  = Stage 1 - SVN operations =
#  ============================

clean_svn_repo()
{
   # Initialize and start with fresh repo
   # Clean Firebot metafiles
   cd $FIREBOT_DIR
   rm output/*

   # Clean up temporary unversioned and modified versioned repository files
   cd $SVNROOT
   svn revert -Rq *
   svn status --no-ignore | grep '^\?' | sed 's/^\?      //'  | xargs -Ixx rm -rf xx
}

do_svn_checkout()
{
   # If an SVN revision number is specified, then get that revision
   if [[ $SVN_REVISION != "" ]]; then
      echo "Checking out revision r${SVN_REVISION}." > $FIREBOT_DIR/output/stage1
      svn update -r $SVN_REVISION >> $FIREBOT_DIR/output/stage1 2>&1
   # If no SVN revision number is specified, then get the latest revision
   else
      echo "Checking out latest revision." > $FIREBOT_DIR/output/stage1
      svn update >> $FIREBOT_DIR/output/stage1 2>&1
      SVN_REVISION=`tail -n 1 $FIREBOT_DIR/output/stage1 | sed "s/[^0-9]//g"`
   fi
}

check_svn_checkout()
{
   cd $SVNROOT
   # Check for SVN errors
   if [[ `grep -E 'Updated|At revision' $FIREBOT_DIR/output/stage1 | wc -l` -ne 1 ]];
   then
      BUILD_STAGE_FAILURE="Stage 1: SVN Operations"
      ERROR_LOG=$FIREBOT_DIR/output/stage1
      save_build_status
      email_error_message
   else
      # Continue along
      :
   fi
}

#  =============================
#  = Stage 2a - Compile FDS DB =
#  =============================

compile_fds_db()
{
   # Clean and compile FDS DB
   cd $SVNROOT/FDS_Compilation/intel_linux_64_db
   make --makefile ../makefile clean &> /dev/null
   ./make_fds.sh &> $FIREBOT_DIR/output/stage2a
}

check_compile_fds_db()
{
   # Check for errors in FDS DB compilation
   cd $SVNROOT/FDS_Compilation/intel_linux_64_db
   if [ -e "fds_intel_linux_64_db" ]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 2a: FDS DB Compilation"
      ERROR_LOG=$FIREBOT_DIR/output/stage2a
      save_build_status
      email_error_message
   fi

   # Check for compiler warnings
   if [[ `grep warning ${FIREBOT_DIR}/output/stage2a` == "" ]]
   then
      # Continue along
      :
   else
      grep warning ${FIREBOT_DIR}/output/stage2a >> $FIREBOT_DIR/output/warnings
   fi
}

#  =================================
#  = Stage 2b - Compile FDS MPI DB =
#  =================================

compile_fds_mpi_db()
{
   # Clean and compile FDS MPI DB
   cd $SVNROOT/FDS_Compilation/mpi_intel_linux_64_db
   make --makefile ../makefile clean &> /dev/null
   ./make_fds.sh &> $FIREBOT_DIR/output/stage2b
}

check_compile_fds_mpi_db()
{
   # Check for errors in FDS MPI DB compilation
   cd $SVNROOT/FDS_Compilation/mpi_intel_linux_64_db
   if [ -e "fds_mpi_intel_linux_64_db" ]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 2b: FDS MPI DB Compilation"
      ERROR_LOG=$FIREBOT_DIR/output/stage2b
      save_build_status
      email_error_message
   fi

   # Check for compiler warnings
   # grep -v 'feupdateenv ...' ignores a known FDS MPI compiler warning (http://software.intel.com/en-us/forums/showthread.php?t=62806)
   if [[ `grep warning ${FIREBOT_DIR}/output/stage2b | grep -v 'feupdateenv is not implemented'` == "" ]]
   then
      # Continue along
      :
   else
      grep warning ${FIREBOT_DIR}/output/stage2b | grep -v 'feupdateenv is not implemented' >> $FIREBOT_DIR/output/warnings
   fi
}

#  =============================
#  = Stage 2c - Compile SMV DB =
#  =============================

compile_smv_db()
{
   # Clean and compile SMV DB
   cd $SVNROOT/SMV/Build/intel_linux_64_dbg
   make --makefile ../Makefile clean &> /dev/null
   ./make_smv.sh &> $FIREBOT_DIR/output/stage2c
}

check_compile_smv_db()
{
   # Check for errors in SMV DB compilation
   cd $SVNROOT/SMV/Build/intel_linux_64_dbg
   if [ -e "smokeview_linux_64_dbg" ]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 2c: SMV DB Compilation"
      ERROR_LOG=$FIREBOT_DIR/output/stage2c
      save_build_status
      email_error_message
   fi

   # Check for compiler warnings
   # grep -v 'feupdateenv ...' ignores a known FDS MPI compiler warning (http://software.intel.com/en-us/forums/showthread.php?t=62806)
   if [[ `grep warning ${FIREBOT_DIR}/output/stage2c | grep -v 'feupdateenv is not implemented' | grep -v 'lcilkrts linked'` == "" ]]
   then
      # Continue along
      :
   else
      grep warning ${FIREBOT_DIR}/output/stage2c | grep -v 'feupdateenv is not implemented' | grep -v 'lcilkrts linked' >> $FIREBOT_DIR/output/warnings
   fi
}

#  ================================================
#  = Stage 3 - Run verification cases (short run) =
#  ================================================

wait_verification_cases_short_start()
{
   # Scans qstat and waits for verification cases to start
   while [[ `qstat | grep $(whoami) | grep Q` != '' ]]; do
      JOBS_REMAINING=`qstat | grep $(whoami) | grep Q | wc -l`
      echo "Waiting for ${JOBS_REMAINING} verification cases to start." >> $FIREBOT_DIR/output/stage3
      sleep 30
   done
}

wait_verification_cases_short_end()
{
   # Scans qstat and waits for verification cases to end
   while [[ `qstat | grep $(whoami)` != '' ]]; do
      JOBS_REMAINING=`qstat | grep $(whoami) | wc -l`
      echo "Waiting for ${JOBS_REMAINING} verification cases to complete." >> $FIREBOT_DIR/output/stage3
      sleep 30
   done
}

run_verification_cases_short()
{
   # Set variables for launching FDS cases on cluster
   cd $SVNROOT/Verification
   export SVNROOT=$SVNROOT
   export FDS=$SVNROOT/FDS_Compilation/intel_linux_64_db/fds_intel_linux_64_db
   export CFAST=~/cfast/CFAST/intel_linux_64/cfast6_linux_64
   export FDSMPI=$SVNROOT/FDS_Compilation/mpi_intel_linux_64_db/fds_mpi_intel_linux_64_db
   export RUNCFAST=$SVNROOT/Utilities/Scripts/runcfast.sh
   export RUNFDS=$SVNROOT/Utilities/Scripts/runfds.sh
   export RUNFDSMPI=$SVNROOT/Utilities/Scripts/runfdsmpi.sh
   export BASEDIR=$SVNROOT/Verification

   #  ========================
   #  = Run all serial cases =
   #  ========================

   # Wait for serial verification cases to start
   ./FDS_Cases.sh &> $FIREBOT_DIR/output/stage3
   wait_verification_cases_short_start

   # Wait some additional time for cases to start
   sleep 30

   # Stop all cases
   export STOPFDS=1
   ./FDS_Cases.sh >> $FIREBOT_DIR/output/stage3 2>&1
   unset STOPFDS

   # Wait for serial verification cases to end
   wait_verification_cases_short_end

   #  =====================
   #  = Run all MPI cases =
   #  =====================

   # Wait for MPI verification cases to start
   ./FDS_MPI_Cases.sh >> $FIREBOT_DIR/output/stage3 2>&1
   wait_verification_cases_short_start

   # Wait some additional time for cases to start
   sleep 30

   # Stop all cases
   export STOPFDS=1
   ./FDS_MPI_Cases.sh >> $FIREBOT_DIR/output/stage3 2>&1
   unset STOPFDS

   # Wait for MPI verification cases to end
   wait_verification_cases_short_end

   #  =====================
   #  = Run all SMV cases =
   #  =====================

   # # Wait for SMV verification cases to start
   # ./scripts/SMV_Cases.sh >> $FIREBOT_DIR/output/stage3 2>&1
   # wait_verification_cases_short_start

   # # Wait some additional time for cases to start
   # sleep 30

   # # Stop all cases
   # export STOPFDS=1
   # ./scripts/SMV_Cases.sh >> $FIREBOT_DIR/output/stage3 2>&1
   # unset STOPFDS

   # # Wait for MPI verification cases to end
   # wait_verification_cases_short_end

   #  ======================
   #  = Remove .stop files =
   #  ======================

   # Remove all .stop files from Verification directories (recursively)
   find . -name '*.stop' -exec rm -f {} \;
}

check_verification_cases_short()
{
   # Scan and report any errors in FDS verification cases
   cd $SVNROOT/Verification

   if [[ `grep 'Run aborted' -rI ${FIREBOT_DIR}/output/stage3` == "" ]] && \
      [[ `grep ERROR: -rI *` == "" ]] && \
      [[ `grep 'STOP: Numerical' -rI *` == "" ]] && \
      [[ `grep -A 20 forrtl -rI *` == "" ]]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 3: FDS Verification Cases"
      
      grep 'Run aborted' -rI $FIREBOT_DIR/output/stage3 >> $FIREBOT_DIR/output/stage3_errors
      grep ERROR: -rI * >> $FIREBOT_DIR/output/stage3_errors
      grep 'STOP: Numerical' -rI * >> $FIREBOT_DIR/output/stage3_errors
      grep -A 20 forrtl -rI * >> $FIREBOT_DIR/output/stage3_errors
      
      ERROR_LOG=$FIREBOT_DIR/output/stage3_errors
      save_build_status
      email_error_message
   fi
}

#  ==========================
#  = Stage 4a - Compile FDS =
#  ==========================

compile_fds()
{
   # Clean and compile FDS
   cd $SVNROOT/FDS_Compilation/intel_linux_64
   make --makefile ../makefile clean &> /dev/null
   ./make_fds.sh &> $FIREBOT_DIR/output/stage4a
}

check_compile_fds()
{
   # Check for errors in FDS compilation
   cd $SVNROOT/FDS_Compilation/intel_linux_64
   if [ -e "fds_intel_linux_64" ]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 4a: FDS Compilation"
      ERROR_LOG=$FIREBOT_DIR/output/stage4a
      save_build_status
      email_error_message
   fi

   # Check for compiler warnings
   if [[ `grep warning ${FIREBOT_DIR}/output/stage4a` == "" ]]
   then
      # Continue along
      :
   else
      grep warning ${FIREBOT_DIR}/output/stage4a >> $FIREBOT_DIR/output/warnings
   fi
}

#  ==============================
#  = Stage 4b - Compile FDS MPI =
#  ==============================

compile_fds_mpi()
{
   # Clean and compile FDS MPI
   cd $SVNROOT/FDS_Compilation/mpi_intel_linux_64
   make --makefile ../makefile clean &> /dev/null
   ./make_fds.sh &> $FIREBOT_DIR/output/stage4b
}

check_compile_fds_mpi()
{
   # Check for errors in FDS MPI compilation
   cd $SVNROOT/FDS_Compilation/mpi_intel_linux_64
   if [ -e "fds_mpi_intel_linux_64" ]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 4b: FDS MPI Compilation"
      ERROR_LOG=$FIREBOT_DIR/output/stage4b
      save_build_status
      email_error_message
   fi

   # Check for compiler warnings
   # grep -v 'feupdateenv ...' ignores a known FDS MPI compiler warning (http://software.intel.com/en-us/forums/showthread.php?t=62806)
   if [[ `grep warning ${FIREBOT_DIR}/output/stage4b | grep -v 'feupdateenv is not implemented'` == "" ]]
   then
      # Continue along
      :
   else
      grep warning ${FIREBOT_DIR}/output/stage4b | grep -v 'feupdateenv is not implemented' >> $FIREBOT_DIR/output/warnings
   fi
}

#  ==========================
#  = Stage 4c - Compile SMV =
#  ==========================

compile_smv()
{
   # Clean and compile SMV
   cd $SVNROOT/SMV/Build/intel_linux_64
   make --makefile ../Makefile clean &> /dev/null
   ./make_smv.sh &> $FIREBOT_DIR/output/stage4c
}

check_compile_smv()
{
   # Check for errors in SMV DB compilation
   cd $SVNROOT/SMV/Build/intel_linux_64
   if [ -e "smokeview_linux_64" ]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 4c: SMV Compilation"
      ERROR_LOG=$FIREBOT_DIR/output/stage4c
      save_build_status
      email_error_message
   fi

   # Check for compiler warnings
   # grep -v 'feupdateenv ...' ignores a known FDS MPI compiler warning (http://software.intel.com/en-us/forums/showthread.php?t=62806)
   if [[ `grep warning ${FIREBOT_DIR}/output/stage4c | grep -v 'feupdateenv is not implemented' | grep -v 'lcilkrts linked'` == "" ]]
   then
      # Continue along
      :
   else
      grep warning ${FIREBOT_DIR}/output/stage4c | grep -v 'feupdateenv is not implemented' | grep -v 'lcilkrts linked' >> $FIREBOT_DIR/output/warnings
   fi
}

#  ===============================================
#  = Stage 5 - Run verification cases (long run) =
#  ===============================================

wait_verification_cases_long_end()
{
   # Scans qstat and waits for verification cases to end
   while [[ `qstat | grep $(whoami)` != '' ]]; do
      JOBS_REMAINING=`qstat | grep $(whoami) | wc -l`
      echo "Waiting for ${JOBS_REMAINING} verification cases to complete." >> $FIREBOT_DIR/output/stage5
      sleep 60
   done
}

run_verification_cases_long()
{
   # Start running all FDS verification cases
   cd $SVNROOT/Verification
   echo 'Running FDS verification cases:' > $FIREBOT_DIR/output/stage5
   ./Run_FDS_Cases.sh >> $FIREBOT_DIR/output/stage5 2>&1
   echo '' >> $FIREBOT_DIR/output/stage5 2>&1

   # Start running all SMV verification cases
   cd $SVNROOT/Verification/scripts
   echo 'Running SMV verification cases:' >> $FIREBOT_DIR/output/stage5 2>&1
   ./Run_SMV_Cases.sh >> $FIREBOT_DIR/output/stage5 2>&1

   # Wait for all verification cases to end
   wait_verification_cases_long_end
}

check_verification_cases_long()
{
   # Scan and report any errors in FDS verification cases
   cd $SVNROOT/Verification

   if [[ `grep 'Run aborted' -rI ${FIREBOT_DIR}/output/stage5` == "" ]] && \
      [[ `grep ERROR: -rI *` == "" ]] && \
      [[ `grep 'STOP: Numerical' -rI *` == "" ]] && \
      [[ `grep -A 20 forrtl -rI *` == "" ]]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 5: FDS-SMV Verification Cases"
      
      grep 'Run aborted' -rI $FIREBOT_DIR/output/stage5 >> $FIREBOT_DIR/output/stage5_errors
      grep ERROR: -rI * >> $FIREBOT_DIR/output/stage5_errors
      grep 'STOP: Numerical' -rI * >> $FIREBOT_DIR/output/stage5_errors
      grep -A 20 forrtl -rI * >> $FIREBOT_DIR/output/stage5_errors
      
      ERROR_LOG=$FIREBOT_DIR/output/stage5_errors
      save_build_status
      email_error_message
   fi
}

#  ====================================
#  = Stage 6a - Compile SMV utilities =
#  ====================================

compile_smv_utilities()
{
   # smokeview test:
   cd $SVNROOT/SMV/Build/intel_linux_test_64
   echo 'Compiling SMV test:' > $FIREBOT_DIR/output/stage6a
   ./make_smv.sh >> $FIREBOT_DIR/output/stage6a 2>&1
   echo '' >> $FIREBOT_DIR/output/stage6a 2>&1
   
   # smokezip:
   cd $SVNROOT/Utilities/smokezip/intel_linux_64
   echo 'Compiling smokezip:' >> $FIREBOT_DIR/output/stage6a 2>&1
   ./make_zip.sh >> $FIREBOT_DIR/output/stage6a 2>&1
   echo '' >> $FIREBOT_DIR/output/stage6a 2>&1
   
   # smokediff:
   cd $SVNROOT/Utilities/smokediff/intel_linux_64
   echo 'Compiling smokediff:' >> $FIREBOT_DIR/output/stage6a 2>&1
   ./make_diff.sh >> $FIREBOT_DIR/output/stage6a 2>&1
   echo '' >> $FIREBOT_DIR/output/stage6a 2>&1
   
   # background:
   cd $SVNROOT/Utilities/background/intel_linux_32
   echo 'Compiling background:' >> $FIREBOT_DIR/output/stage6a 2>&1
   ./make_background.sh >> $FIREBOT_DIR/output/stage6a 2>&1
}

check_smv_utilities()
{
   # Check for errors in SMV utilities compilation
   cd $SVNROOT
   if [ -e "$SVNROOT/SMV/Build/intel_linux_test_64/smokeview_linux_test_64" ]  && \
      [ -e "$SVNROOT/Utilities/smokezip/intel_linux_64/smokezip_linux_64" ]  && \
      [ -e "$SVNROOT/Utilities/smokediff/intel_linux_64/smokediff_linux_64" ]  && \
      [ -e "$SVNROOT/Utilities/background/intel_linux_32/background" ]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 6: SMV Utilities Compilation"
      ERROR_LOG=$FIREBOT_DIR/output/stage6a
      save_build_status
      email_error_message
   fi
}

#  ================================
#  = Stage 6b - Make FDS pictures =
#  ================================

make_fds_pictures()
{
   # Run Make FDS Pictures script
   cd $SVNROOT/Verification
   ./Make_FDS_Pictures.sh &> $FIREBOT_DIR/output/stage6b
}

check_fds_pictures()
{
   # Scan and report any errors in make FDS pictures process
   cd $FIREBOT_DIR
   if [[ `grep -B 50 -A 50 "Segmentation" -I $FIREBOT_DIR/output/stage6b` == "" ]]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 6b: Make FDS Pictures"
      grep -B 50 -A 50 "Segmentation" -I $FIREBOT_DIR/output/stage6b > $FIREBOT_DIR/output/stage6b_errors
      ERROR_LOG=$FIREBOT_DIR/output/stage6b_errors
      save_build_status
      email_error_message
   fi
}

#  ================================
#  = Stage 6c - Make SMV pictures =
#  ================================

make_smv_pictures()
{
   # Run Make SMV Pictures script
   cd $SVNROOT/Verification/scripts
   ./Make_SMV_Pictures.sh &> $FIREBOT_DIR/output/stage6c
}

check_smv_pictures()
{
   # Scan and report any errors in make SMV pictures process
   cd $FIREBOT_DIR
   if [[ `grep -B 50 -A 50 "Segmentation" -I $FIREBOT_DIR/output/stage6c` == "" ]]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 6c: Make SMV Pictures"
      grep -B 50 -A 50 "Segmentation" -I $FIREBOT_DIR/output/stage6c > $FIREBOT_DIR/output/stage6c_errors
      ERROR_LOG=$FIREBOT_DIR/output/stage6c_errors
      save_build_status
      email_error_message
   fi
}

#  ============================================
#  = Stage 7 - Matlab plotting and statistics =
#  ============================================

run_matlab_plotting()
{
   # Run Matlab plotting script
   cd $SVNROOT/Utilities/Matlab/scripts

   # Replace LaTeX with TeX for Interpreter in plot_style.m
   # This allows displayless automatic Matlab plotting
   # Otherwise Matlab crashes due to a known bug
   sed -i 's/LaTeX/TeX/g' plot_style.m 

   cd $SVNROOT/Utilities/Matlab
   matlab -r "try, disp('Running Matlab Verification script'), FDS_verification_script, catch, disp('Matlab error'), err = lasterror, err.message, err.stack, end, exit" &> $FIREBOT_DIR/output/stage7_verification
   matlab -r "try, disp('Running Matlab Validation script'), FDS_validation_script, catch, disp('Matlab error'), err = lasterror, err.message, err.stack, end, exit" &> $FIREBOT_DIR/output/stage7_validation
}

check_matlab_plotting()
{
   # Scan and report any errors in Matlab scripts
   cd $FIREBOT_DIR
   if [[ `grep -A 50 "Matlab error" $FIREBOT_DIR/output/stage7*` == "" ]]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 7: Matlab plotting and statistics"
      grep -A 50 "Matlab error" $FIREBOT_DIR/output/stage7* > $FIREBOT_DIR/output/stage7_errors
      ERROR_LOG=$FIREBOT_DIR/output/stage7_errors
      save_build_status
      email_error_message
   fi
}

#  ==================================
#  = Stage 8 - Build FDS-SMV Guides =
#  ==================================

make_fds_user_guide()
{
   # Build FDS User Guide
   cd $SVNROOT/Manuals/FDS_User_Guide
   pdflatex -interaction nonstopmode FDS_User_Guide &> $FIREBOT_DIR/output/stage8_fds_user_guide
   bibtex FDS_User_Guide >> $FIREBOT_DIR/output/stage8_fds_user_guide 2>&1
   pdflatex -interaction nonstopmode FDS_User_Guide >> $FIREBOT_DIR/output/stage8_fds_user_guide 2>&1
   pdflatex -interaction nonstopmode FDS_User_Guide >> $FIREBOT_DIR/output/stage8_fds_user_guide 2>&1
}

make_fds_technical_guide()
{
   # Build FDS Technical Guide
   cd $SVNROOT/Manuals/FDS_Technical_Reference_Guide
   pdflatex -interaction nonstopmode FDS_Technical_Reference_Guide &> $FIREBOT_DIR/output/stage8_fds_technical_guide
   bibtex FDS_Technical_Reference_Guide >> $FIREBOT_DIR/output/stage8_fds_technical_guide 2>&1
   pdflatex -interaction nonstopmode FDS_Technical_Reference_Guide >> $FIREBOT_DIR/output/stage8_fds_technical_guide 2>&1
   pdflatex -interaction nonstopmode FDS_Technical_Reference_Guide >> $FIREBOT_DIR/output/stage8_fds_technical_guide 2>&1
}

make_fds_verification_guide()
{
   # Build FDS Verification Guide
   cd $SVNROOT/Manuals/FDS_Verification_Guide
   pdflatex -interaction nonstopmode FDS_Verification_Guide &> $FIREBOT_DIR/output/stage8_fds_verification_guide
   bibtex FDS_Verification_Guide >> $FIREBOT_DIR/output/stage8_fds_verification_guide 2>&1
   pdflatex -interaction nonstopmode FDS_Verification_Guide >> $FIREBOT_DIR/output/stage8_fds_verification_guide 2>&1
   pdflatex -interaction nonstopmode FDS_Verification_Guide >> $FIREBOT_DIR/output/stage8_fds_verification_guide 2>&1
}

make_fds_validation_guide()
{
   # Build FDS Validation Guide
   cd $SVNROOT/Manuals/FDS_Validation_Guide
   pdflatex -interaction nonstopmode FDS_Validation_Guide &> $FIREBOT_DIR/output/stage8_fds_validation_guide
   bibtex FDS_Validation_Guide >> $FIREBOT_DIR/output/stage8_fds_validation_guide 2>&1
   pdflatex -interaction nonstopmode FDS_Validation_Guide >> $FIREBOT_DIR/output/stage8_fds_validation_guide 2>&1
   pdflatex -interaction nonstopmode FDS_Validation_Guide >> $FIREBOT_DIR/output/stage8_fds_validation_guide 2>&1
}

make_smv_user_guide()
{
   # Build SMV User Guide
   cd $SVNROOT/Manuals/SMV_User_Guide
   pdflatex -interaction nonstopmode SMV_User_Guide &> $FIREBOT_DIR/output/stage8_smv_user_guide
   bibtex SMV_User_Guide >> $FIREBOT_DIR/output/stage8_smv_user_guide 2>&1
   pdflatex -interaction nonstopmode SMV_User_Guide >> $FIREBOT_DIR/output/stage8_smv_user_guide 2>&1
   pdflatex -interaction nonstopmode SMV_User_Guide >> $FIREBOT_DIR/output/stage8_smv_user_guide 2>&1
}

make_smv_verification_guide()
{
   # Build SMV Verification Guide
   cd $SVNROOT/Manuals/SMV_Verification_Guide
   pdflatex -interaction nonstopmode SMV_Verification_Guide &> $FIREBOT_DIR/output/stage8_smv_verification_guide
   bibtex SMV_Verification_Guide >> $FIREBOT_DIR/output/stage8_smv_verification_guide 2>&1
   pdflatex -interaction nonstopmode SMV_Verification_Guide >> $FIREBOT_DIR/output/stage8_smv_verification_guide 2>&1
   pdflatex -interaction nonstopmode SMV_Verification_Guide >> $FIREBOT_DIR/output/stage8_smv_verification_guide 2>&1
}

check_all_guides()
{
   # Scan and report any errors in FDS Verification Guide build process
   cd $FIREBOT_DIR
   if [[ `grep "! LaTeX Error:" -I $FIREBOT_DIR/output/stage8*` == "" ]]
   then
      # Continue along
      :
   else
      BUILD_STAGE_FAILURE="Stage 8: FDS-SMV Guides"
      grep "! LaTeX Error:" -I $FIREBOT_DIR/output/stage8* > $FIREBOT_DIR/output/stage8_errors
      ERROR_LOG=$FIREBOT_DIR/output/stage8_errors
      save_build_status
      email_error_message
   fi
}

#  ==================================================
#  = Build status report - email and save functions =
#  ==================================================

email_success_message()
{
   cd $FIREBOT_DIR
   # Check for compiler warnings
   if [ -e "output/warnings" ]
   then
      # Send email with success message, include compiler warnings
      mail -s "[Firebot] Build success, with compiler warnings. Revision ${SVN_REVISION} passed all build tests." $mailTo < ${FIREBOT_DIR}/output/warnings > /dev/null
   else
      # Send empty email with success message
      mail -s "[Firebot] Build success! Revision ${SVN_REVISION} passed all build tests." $mailTo < /dev/null > /dev/null
   fi
}

email_error_message()
{
   cd $FIREBOT_DIR
   # Check for compiler warnings
   if [ -e "output/warnings" ]
   then
      cat output/warnings >> $ERROR_LOG

      # Send email with failure message and warnings, body of email contains appropriate log file
      mail -s "[Firebot] Build failure, with compiler warnings! Revision ${SVN_REVISION} build failure at ${BUILD_STAGE_FAILURE}." $mailTo < ${ERROR_LOG} > /dev/null
   else
      # Send email with failure message, body of email contains appropriate log file
      mail -s "[Firebot] Build failure! Revision ${SVN_REVISION} build failure at ${BUILD_STAGE_FAILURE}." $mailTo < ${ERROR_LOG} > /dev/null
   fi
   exit
}

save_build_status()
{
   cd $FIREBOT_DIR
   # Save status outcome of build to a text file
   if [[ $BUILD_STAGE_FAILURE != "" ]]
   then
      echo "Revision ${SVN_REVISION} build failure at ${BUILD_STAGE_FAILURE}." > "$FIREBOT_DIR/history/${SVN_REVISION}.txt"
      cat $ERROR_LOG > "$FIREBOT_DIR/history/${SVN_REVISION}_errors.txt"
   else
      if [ -e "output/warnings" ]
         then 
         echo "Revision ${SVN_REVISION} has compiler warnings." > "$FIREBOT_DIR/history/${SVN_REVISION}.txt"
         cat $FIREBOT_DIR/output/warnings > "$FIREBOT_DIR/history/${SVN_REVISION}_warnings.txt"
      else
         echo "Build success! Revision ${SVN_REVISION} passed all build tests." > "$FIREBOT_DIR/history/${SVN_REVISION}.txt"
      fi
   fi
}

#  ============================
#  = Primary script execution =
#  ============================

### Stage 1 ###
clean_svn_repo
do_svn_checkout
check_svn_checkout

### Stage 2a ###
compile_fds_db
check_compile_fds_db

### Stage 2b ###
compile_fds_mpi_db
check_compile_fds_mpi_db

### Stage 2c ###
compile_smv_db
check_compile_smv_db

### Stage 3 ###
run_verification_cases_short
check_verification_cases_short

### Stage 4a ###
compile_fds
check_compile_fds

### Stage 4b ###
compile_fds_mpi
check_compile_fds_mpi

### Stage 4c ###
compile_smv
check_compile_smv

### Stage 5 ###
run_verification_cases_long
check_verification_cases_long

### Stage 6a ###
compile_smv_utilities
check_smv_utilities

### Stage 6b ###
make_fds_pictures
check_fds_pictures

### Stage 6c ###
make_smv_pictures
check_smv_pictures

### Stage 7 ###
run_matlab_plotting
check_matlab_plotting

### Stage 8 ###
make_fds_user_guide
make_fds_technical_guide
make_fds_verification_guide
make_fds_validation_guide
make_smv_user_guide
make_smv_verification_guide
check_all_guides

### Success! ###
email_success_message
save_build_status
