      module mchr
!
!  Purpose---
!     Character manipulation routines
!
!  Modules used---
!     NONE
!
      implicit none
      private
!
!  Public subroutines---
      public :: chr_upper
      public :: chr_revers
      public :: chr_rmblnk
      public :: chr_lower
!
      contains
!
!==============================================================================!
!
      subroutine chr_lower( string)
!
!  Purpose---
!     Convert character string to all lowercase
!
!  Arguments---
      character(*), intent(inout) :: string
!
!  Fortran functions called---
      intrinsic   char, ichar, len_trim, lgt, llt
!
!  Local variables---
      integer        :: n
      character(1)   :: ch
!
!  Executable statements---
!
      do n = 1, len_trim(string)
         ch = string(n:n)
         if ( llt(ch,'A') .or. lgt(ch,'Z')) cycle
         ch = char( ichar( ch) - ichar('A') + ichar('a'))
         string(n:n) = ch
      enddo
!
      end subroutine chr_lower
!
!==============================================================================!
!
      subroutine  chr_revers( string)
!
!  Purpose---
!     Revers characters in string ( ABC -> CBA)
!
!  Arguments---
      character(*), intent(inout) :: string
!
!  Fortran functions called---
      intrinsic   len
!
!  Local variables---
      integer        :: i, j, k, ll
      character(1)   :: ch
!
!  Executable statements---
!
      ll = len(string)
      if (ll == 0)  return
!
      k  = ll/2
      do i = 1, k
         j  = ll - i + 1
         ch = string(j:j)
         string(j:j) = string(i:i)
         string(i:i) = ch
      enddo
!
      end subroutine chr_revers
!
!==============================================================================!
!
      subroutine  chr_rmblnk( string)
!
!  Purpose---
!     Remove  blanks from character string  
!
!  Note---
!     input:   __cc__ccc__c
!     output:  cccccc______
!
!  Arguments---
      character(*), intent(inout) :: string
!
!  Fortran functions called---
      intrinsic   ichar, len_trim
!
!  Local variables---
      integer        :: i, ll
      character(1)   :: ch
!
!  Executable statements---
!
      ll = len_trim(string)
      i = 1
      do while (i < ll) 
         ch = string(i:i)
         if (ch == ' ') then
            string(i:ll - 1) = string(i+1:ll)
            string(ll:ll)    = ' '
            ll = ll - 1
         else
            i = i + 1
         endif
      enddo
!
      end subroutine chr_rmblnk
!
!==============================================================================!
!
      subroutine chr_upper( string)
!
!  Purpose---
!     Convert character string to all uppercase
!
!  Arguments---
      character(*), intent(inout) :: string
!
!  Fortran functions called---
      intrinsic   char, ichar, len_trim, lgt, llt
!
!  Local variables---
      integer        :: n
      character(1)   :: ch
!
!  Executable statements---
!
      do n = 1, len_trim(string)
         ch = string(n:n)
         if ( llt(ch,'a') .or. lgt(ch,'z')) cycle
         ch = char( ichar( ch) + ichar('A') - ichar('a'))
         string(n:n) = ch
      enddo
!
      end subroutine chr_upper
!
!==============================================================================!
!
      end module mchr