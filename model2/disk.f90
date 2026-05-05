      subroutine disk( n, t, x, dxdt, rpar, ipar)
!
!  Modules used---
      use disk_data, only: g,  xk12, xk22, &
      &  mode, rolling, sliding
      use cdata
!
      implicit none
!            
!  Arguments---
      integer, intent(in)     :: n        ! number of equations
      real(8), intent(in)     :: t        ! current time
      real(8), intent(in)     :: x(*)     ! unknowns
      real(8), intent(out)    :: dxdt(*)  ! derivatives of unknowns 
      real(8), intent(inout)  :: rpar(*)  ! dummy
      integer, intent(inout)  :: ipar(*)  ! dummy
!
!  FORTRAN functions called---
      intrinsic   abs, cos, sin, sign, sqrt
!
!  Function called---
!     NONE
!
!  Subroutines called---
      interface
         subroutine disk0
         end subroutine
      end interface
!
!  Local parameters---
!     NONE
!
!  Local scalars---
!     NONE
!
!  Local arrays---
!     NONE
!
!  Executable statements---
!
!     Localize data
!
      psi    = x(1)
      theta  = x(2)
      phi    = x(3)
      omega1 = x(4)
      omega2 = x(5)
      omega3 = x(6)
      xxc    = x(7)
      yyc    = x(8)
!
      if (mode == sliding) then
         vcx   = x(9)
         vcy   = x(10)
      endif
!
      call disk0
!
!     Form equations
!
      dxdt(1) = omega3/coth
      dxdt(2) = omega1
      dxdt(3) = omega2 - tanth*omega3
!
      dxdt(4) = ( a*omega3 - zp*fy + (yp + xm1)*fz)/xk12
      dxdt(5) = (-rp*fx + xm2*fz)/xk22
      dxdt(6) = (-a*omega1 + hp*fx + xm3*fz)/xk12
!
      dxdt(7) = vcx*copsi - vcy*sipsi
      dxdt(8) = vcx*sipsi + vcy*copsi
!
      if (mode == sliding) then
         dxdt(9) =   vcy*omega3/coth + fx
         dxdt(10) = -vcx*omega3/coth + fy
      endif
!
      end subroutine disk
