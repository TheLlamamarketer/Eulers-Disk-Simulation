      PROGRAM CMAIN
!
!  Purpose---
!     Euler's Disk Simulation
!
!  Modules used---
      USE MUI
      USE DISK_DATA, ONLY: CGRAF, CTIME, CDATE, CVERS
!
      IMPLICIT NONE
!
!  FORTRAN functions called---
      INTRINSIC   LEN
!
!  Parameters---
      CHARACTER(*), PARAMETER :: &
      &  TITLE = '*   EULER''S DISK ROLLING SIMULATION   *'
!
!  Variables---
      INTEGER :: IER,NCH
      LOGICAL :: BANS
      CHARACTER(60) :: CLINE
!
!  Executable statements---
!
!     Print head
!
      NCH = LEN( TITLE)
      CLINE(1:)      = ' '
      CLINE(1:1)     = '*'
      CLINE(NCH:NCH) = '*'
!
      CALL SET_LINE  (NCH,'*')
      CALL SET_STRING( 1,CLINE)
      CALL SET_STRING( 1,TITLE)
      CALL SET_STRING( 1,CLINE)
      CALL SET_LINE  (NCH,'*')
      CALL SKIP_LINES(1)
      CALL SET_STRING(1,CVERS)
      CALL SKIP_LINES(1)
!
!     Main dialog
!
      INQUIRE(FILE = CGRAF, EXIST = BANS)
      IF (BANS) THEN
         CALL GET_YESNO('Show existing simulation ?',BANS,.FALSE.,IER)
      ENDIF
      IF (.NOT.BANS) THEN
!
!        New calculation
!
         CALL SET_STRING(1,'New simulation')
         CALL INPUT
         CALL INTEG
         CALL POST
      ELSE
      ENDIF
!
      CALL SET_STRING(1,'Start OpenGL animation...')
      CALL SET_STRING(4,'Use mouse to zoom or rotate')
      CALL SET_STRING(4,'Use arrow key to pan')
      CALL SET_STRING(4,'Use a/A key autopan')
      CALL SET_STRING(4,'Use s/S key to stop, r/R key to restart')
      CALL SET_STRING(4,'Use + to speedup/slowdown or/and enter number 1..9')
      CALL SET_STRING(4,'Use t/T key to show time')
      CALL SET_STRING(4,'Use ESC key to QUIT')
!
      CALL MY_ANIMATION
!
      END PROGRAM CMAIN