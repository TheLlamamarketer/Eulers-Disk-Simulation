      real(8) function ztime( t)
!
!  Modules used---
      use cdata, only: p, ndeg
!
      implicit none
!         
!  Arguments---
      real(8), intent(in) :: t
!
!  Local varibles---
      integer :: n
!
!  Executable statements---
!
      ztime = p(ndeg)
      do n = ndeg - 1, 0, -1
         ztime = p(n) + ztime*t
      enddo
!
      end function ztime
