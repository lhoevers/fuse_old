SUBROUTINE GETFORCING(INFERN_START,NTIM,err,message)
! ---------------------------------------------------------------------------------------
! Creator:
! --------
! Martyn Clark, 2009
! Modified by Brian Henn to include snow model, 7/2013
! ---------------------------------------------------------------------------------------
! Purpose:
! --------
! Read ASCII model forcing data in BATEA format
! ---------------------------------------------------------------------------------------
! Modules Modified:
! -----------------
! MODULE multiforce -- populate structure AFORCE(*)%(*)
! ---------------------------------------------------------------------------------------
use nrtype,only:I4B,LGT,SP
use utilities_dmsl_kit_FUSE,only:getSpareUnit,stripTrailString
USE fuse_fileManager,only:SETNGS_PATH,FORCINGINFO     ! defines data directory 
USE multiforce,only:AFORCE,DELTIM,ISTART,NUMTIM       ! model forcing structures
USE multiroute,only:AROUTE                            ! model routing structure
IMPLICIT NONE
! dummies
INTEGER(I4B), INTENT(OUT)              :: INFERN_START ! index of start of inference period
INTEGER(I4B), INTENT(OUT)              :: NTIM         ! index of start of inference period
integer(I4B), intent(out)              :: err
character(*), intent(out)              :: message
! internal
integer(i4b),parameter::lenPath=1024 ! DK/2008/10/21: allows longer file paths
INTEGER(I4B),DIMENSION(10)             :: IERR        ! error codes
INTEGER(I4B)                           :: IUNIT       ! input file unit
CHARACTER(LEN=lenPath)                 :: CFILE       ! name of control file
CHARACTER(LEN=lenPath)                 :: FFILE       ! name of forcing file
LOGICAL(LGT)                           :: LEXIST      ! .TRUE. if control file exists
CHARACTER(LEN=lenPath)                 :: FNAME_INPUT ! name of input file
INTEGER(I4B)                           :: NCOL        ! number of columns
INTEGER(I4B)                           :: IX_PPT      ! column number for precipitation
INTEGER(I4B)                           :: IX_PET      ! column number for potential ET
INTEGER(I4B)                           :: IX_TEMP     ! column number for temperature
INTEGER(I4B)                           :: IX_OBSQ     ! column number for observed streamflow
INTEGER(I4B)                           :: NHEAD       ! number of header rows
INTEGER(I4B)                           :: WARM_START  ! index of start of warm-up period
INTEGER(I4B)                           :: INFERN_END  ! index of start of inference period
INTEGER(I4B)                           :: NSTEPS      ! number of time steps desired
INTEGER(I4B)                           :: IHEAD       ! header index
CHARACTER(LEN=lenPath)                 :: TMPTXT      ! descriptive text
INTEGER(I4B)                           :: ITIME       ! time index (input data)
INTEGER(I4B)                           :: JTIME       ! time index (internal data structure)
REAL(SP),DIMENSION(:),ALLOCATABLE      :: TMPDAT      ! one line of data
! ---------------------------------------------------------------------------------------
! read in control file
err=0
CFILE = TRIM(SETNGS_PATH)//TRIM(FORCINGINFO)      ! control file info shared in MODULE directory
INQUIRE(FILE=CFILE,EXIST=LEXIST)  ! check that control file exists

IF (.NOT.LEXIST) THEN
 message = 'f-GETFORCING/control file '//TRIM(CFILE)//' for forcing data does not exist ' 
 err=100; return
ENDIF

! read in parameters of the control file
CALL getSpareUnit(IUNIT,err,message) ! make sure IUNIT is actually available
  IF (err/=0) THEN
  message="f-GETFORCING/weird/&"//message
  err=100; return
ENDIF

OPEN(IUNIT,FILE=CFILE,STATUS='old')           
READ(IUNIT,'(A)') FNAME_INPUT                        ! get input filename
READ(IUNIT,*) NCOL,IX_PPT,IX_PET,IX_OBSQ,IX_TEMP        ! number of columns and column numbers
READ(IUNIT,*) NHEAD,WARM_START,INFERN_START,INFERN_END  ! n header, start warm-up, start inference, end inference
CLOSE(IUNIT)
! subtract the header lines from the data indices
WARM_START   = WARM_START   - NHEAD
INFERN_START = INFERN_START - NHEAD
INFERN_END   = INFERN_END   - NHEAD
! fill extra characters in filename with white space
CALL stripTrailString(string=FNAME_INPUT,trailStart='!')
! ---------------------------------------------------------------------------------------
! allocate space for data structures
IERR   = 0
NSTEPS = (INFERN_END-WARM_START)+1
!WRITE(*,*) NHEAD,WARM_START,INFERN_START,INFERN_END,NSTEPS
IF (WARM_START.GT.INFERN_START) THEN
 message='f-GETFORCING/start of inference is greater than the start of warm-up'
 err=100; RETURN
END IF 
IF (INFERN_START.GT.INFERN_END) THEN
 message='f-GETFORCING/start of inference is greater than the end of inference'
 err=100; RETURN
END IF
ALLOCATE(TMPDAT(NCOL)  ,STAT=IERR(1))  ! (only used in this routine -- deallocate later)
ALLOCATE(AFORCE(NSTEPS),STAT=IERR(2))  ! (shared in module multiforce)
ALLOCATE(AROUTE(NSTEPS),STAT=IERR(3))  ! (shared in module multiroute)
IF (ANY(IERR.NE.0)) THEN
 message='f-GETFORCING/problem allocating data structures'
 err=100; RETURN
END IF
! initialize the Q_ACCURATE vector
AROUTE(1:NSTEPS)%Q_ACCURATE = -9999._SP
! ---------------------------------------------------------------------------------------
! read data
JTIME = 0
FFILE = TRIM(SETNGS_PATH)//FNAME_INPUT
INQUIRE(FILE=FFILE,EXIST=LEXIST)  ! check that control file exists
IF (.NOT.LEXIST) THEN
 message='f-getforcing/forcing data file '//TRIM(FFILE)//' does not exist '
 err=100; return
ENDIF
CALL getSpareUnit(IUNIT,err,message) ! make sure IUNIT is actually available
IF (err/=0) THEN
 message="f-GETFORCING/weird/&"//message
 err=100; return
ENDIF
OPEN(IUNIT,FILE=FFILE,STATUS='old')
! read header
DO IHEAD=1,NHEAD
 IF (IHEAD.EQ.2) THEN
  READ(IUNIT,*) DELTIM   ! time interval of the data (shared in module multiforce)
 ELSE
  READ(IUNIT,*) TMPTXT   ! descriptive text
 ENDIF
END DO
! read data
DO ITIME=1,INFERN_END
 READ(IUNIT,*) TMPDAT
 !WRITE(*,'(2(I6,1X),F5.0,1X,3(F3.0,1X)') ITIME,WARM_START,TMPDAT(1:4)
 IF (ITIME.GE.WARM_START) THEN
  JTIME = JTIME+1
  AFORCE(JTIME)%IY    = INT(TMPDAT(1))
  AFORCE(JTIME)%IM    = INT(TMPDAT(2))
  AFORCE(JTIME)%ID    = INT(TMPDAT(3))
  AFORCE(JTIME)%IH    = INT(TMPDAT(4))
  AFORCE(JTIME)%IMIN  = 0
  AFORCE(JTIME)%DSEC  = 0._SP
  AFORCE(JTIME)%DTIME = 0._SP
  AFORCE(JTIME)%PPT   = TMPDAT(IX_PPT)
  AFORCE(JTIME)%TEMP  = TMPDAT(IX_TEMP)
  AFORCE(JTIME)%PET   = TMPDAT(IX_PET)
  AFORCE(JTIME)%OBSQ  = TMPDAT(IX_OBSQ)
  !WRITE(*,'(2(I6,1X),F5.0,1X,3(F3.0,1X),3(F12.4,1X))') ITIME, JTIME, TMPDAT(1:4), &
  ! AFORCE(JTIME)%PPT, AFORCE(JTIME)%PET, AFORCE(JTIME)%OBSQ
 ENDIF
END DO
CLOSE(IUNIT)
! correct the index for start of inference
INFERN_START = (INFERN_START-WARM_START)+1
ISTART       = INFERN_START ! (shared in MODULE multiforce)
!WRITE(*,'(I6,1X,I4,1X,3(I2,1X),3(F12.4,1X))') ISTART, &
! AFORCE(ISTART)%IY,  AFORCE(ISTART)%IM,  AFORCE(ISTART)%ID, AFORCE(ISTART)%IH, &
! AFORCE(ISTART)%PPT, AFORCE(ISTART)%PET, AFORCE(ISTART)%OBSQ
! save the number of time steps
NTIM   = NSTEPS     ! number of time steps (returned to main program)
NUMTIM = NSTEPS     ! number of time steps (shared in MODULE multiforce)
DEALLOCATE(TMPDAT, STAT=IERR(1))
IF (IERR(1).NE.0) THEN
 message='f-GETFORCING/problem deallocating TMPDAT'
 err=100; RETURN
END IF
! ---------------------------------------------------------------------------------------
END SUBROUTINE GETFORCING
