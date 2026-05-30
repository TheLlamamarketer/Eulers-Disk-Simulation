! Copyright (c) 1994 Unicomp, Inc.  All rights reserved.
!
! Developed at Unicomp, Inc.
!
! Permission to use, copy, modify, and distribute this
! software is freely granted, provided that this notice 
! is preserved.
!
      module mIO
!
!  Modules used---
!     NONE
!
      implicit none
      private
!
! Public routines---
      public :: new_unit
!
! Public parameters---
!
!     Default input and output units:
!
      integer, public, parameter :: DEFAULT_INPUT_UNIT  = 5
      integer, public, parameter :: DEFAULT_OUTPUT_UNIT = 6
!
!     Values returned to IOSTAT for end of record and end of file
!
      integer, public, parameter :: END_OF_RECORD = -2
      integer, public, parameter :: END_OF_FILE   = -1
!
!  Private parameters---
!
!     Number and value of preconnected units
!
      integer, parameter :: NUMBER_OF_PRECONNECTED_UNITS = 3
      integer, parameter :: PRECONNECTED_UNITS (NUMBER_OF_PRECONNECTED_UNITS) = &
      &                     (/ 0, 5, 6 /)
!
!     Largest allowed unit number (or a large number, if none)
!
      integer, parameter :: MAX_UNIT_NUMBER = 1000
!
contains
!
      subroutine new_unit ( iunit, stat)
!
!  Purpose---
!     Returns a unit number of a unit that exists and is not connected
!  
!  Arguments---
      integer, intent( out) :: iunit   ! free unit number
!
!  Optional arguments---
      integer, optional, intent(out) :: stat    ! status of return (0=OK)
!
!  Local variables---
      logical :: exists, opened
      integer :: ios
!   
!  Executable statements---
!
      do iunit = 0, MAX_UNIT_NUMBER
         if (iunit == DEFAULT_INPUT_UNIT .or. &
         &   iunit == DEFAULT_OUTPUT_UNIT) cycle
         if (any (iunit == PRECONNECTED_UNITS)) cycle
         inquire ( &
         &  unit   = iunit,   &
         &  exist  = exists,  &
         &  opened = opened,  &
         &  iostat = ios)
         if (exists .and. .not. opened .and. ios == 0) exit
      end do
!   
      if (iunit > MAX_UNIT_NUMBER) iunit = -1
!
      if (present(stat)) stat = ios
!   
   end subroutine new_unit
!
end module mIO

