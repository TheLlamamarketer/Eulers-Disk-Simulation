module mn2c
!
!  Purpose---
!     Convert number to character string
!
!  Syntax---
!     call  n2c( val, string, [fmt], [stat])
!
!     Arguments:
!        val      number         in    double, integer , real value
!        string   character(*)   out   string
!
!     Optional arguments:
!        fmt      character(*)   in    number format (ex. 'f9.4')
!        stat     integer        out   status of return (0=OK)
!
!  Modules used---
!     NONE
!
   implicit none
   private
!
!  Public subroutines---
      public :: n2c
!
!  Interfaces---
      interface n2c
         module procedure d2c, i2c, r2c
      end interface
!
contains
!
!==============================================================================!
!
subroutine d2c( dnum, cnum, cfmt, stat)
!
!  Purpose---
!     Convert double to string
!
!  Arguments---
      real(8),      intent(in)  :: dnum
      character(*), intent(out) :: cnum
!
!  Optional arguments---
      character(*), optional, intent(in)  :: cfmt
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic  len, repeat
!
!  Local variables---
      integer :: ier
!
!  Executable statements---
!
      ier = 0
      if (present(cfmt)) then
         write( cnum, cfmt, iostat = ier) dnum
      else
         write(cnum, * , iostat = ier) dnum
      endif
!
      if (ier /= 0) cnum = repeat('*',len(cnum))
!
      if (present(stat)) stat = ier
!
end subroutine d2c
!
!==============================================================================!
!
subroutine i2c( inum, cnum, cfmt, stat)
!
!  Purpose---
!     Convert integer to string
!
!  Arguments---
      integer,      intent(in)  :: inum
      character(*), intent(out) :: cnum
!
!  Optional arguments---
      character(*), optional, intent(in)  :: cfmt
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic  len, repeat
!
!  Local variables---
      integer :: ier
!
!  Executable statements---
!
      ier = 0
!
      if (present(cfmt)) then
         write( cnum, cfmt, iostat = ier) inum
      else
         write(cnum, * , iostat = ier) inum
      endif
!
      if (ier /= 0) cnum = repeat('*',len(cnum))
!
      if (present(stat)) stat = ier
!
end subroutine i2c
!
!==============================================================================!
!
subroutine r2c( rnum, cnum, cfmt, stat)
!
!  Purpose---
!     Convert real to string
!
!  Arguments---
      real(4),      intent(in)  :: rnum
      character(*), intent(out) :: cnum
!
!  Optional arguments---
      character(*), optional, intent(in)  :: cfmt
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic  len, repeat
!
!  Local variables---
      integer :: ier
!
!  Executable statements---
!
      ier = 0
!
      if (present(cfmt)) then
         write( cnum, cfmt, iostat = ier) rnum
      else
         write(cnum, *, iostat = ier) rnum
      endif
!
      if (ier /= 0) cnum = repeat('*',len(cnum))
!
      if (present(stat)) stat = ier
!
end subroutine r2c
!
!==============================================================================!
!
end module mn2c