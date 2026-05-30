      subroutine input
!
!  Purpose---
!     Driver routine
!
!  Modules used---
      use disk_data
      use mui, only: get_number, set_string
!
      implicit none
!
!  Local parameters---
!      real(8), parameter :: ZERO = 0.0_8, ONE = 1.0_8
!
!  Local variables---
      integer :: ier
!
!  Executable statements---
!
      call date_and_time( cdate, ctime)
      cdate(:) = cdate(7:8)//'/'//cdate(5:6)//'/'//cdate(1:4)
      ctime(:) = ctime(1:2)//':'//ctime(3:4)//':'//ctime(5:6)
!
!     Initial values are exact Euler's disk geometry values /Kessler pp 56/
!
      r     = 37.55e-3_8
      h     = 12.80e-3_8
      rho   =  3.00e-3_8
      hh    =  H/2.0_8
      xmass =  0.4387_8
      call prop( r, h, rho, xk12, xk22)
!
      tstart = 0.0_8
      tend   = 200.0*0.0691712 
!
!     Default initial values from Kessler 
!
      psi0   = ZERO
      theta0 = ONE 
      phi0   = ZERO
! 
      omega10 = ZERO 
      omega20 = ZERO  
      omega30 = -1.0/0.0691712  
!
      xxc0   = ZERO
      yyc0   = ZERO
!
      vcx0   = ZERO
      vcy0   = ZERO
      vcz0   = ZERO
!
      xmus   = 0.5_8
      xmud   = 0.3_8
!
      xmurx  = 0.0001*R 
      xmury  = 0.0008*R 
      xmurz  = 0.0080*R 
!
!     DOPRI stuff
!
!
      reltol = 1.0E-8_8
      abstol = reltol
      tprint = 0.001_8
      tout   = tstart
!
!     Get values
!
      call get_number('Disk radius    [m]    ',r,   stat = ier)
      if (ier /= 0) goto 999      
      call get_number('Disk height    [m]    ',h ,  stat = ier)
      if (ier /= 0) goto 999
      hh = h/2.0_8
      if (hh /= zero) then
      rho = 0.002
      call get_number('Disk filet     [m]    ',rho, minv = 0.0_8, maxv = hh, stat = ier)
      if (ier /= 0) goto 999
      else
         rho=zero
      endif
!
      call get_number('Initial Z-rot  [rad]  ',PSI0, stat = ier)
      if (ier /= 0) goto 999
      call get_number('Initial X-rot  [rad]  ',THETA0, stat = ier)
      if (ier /= 0) goto 999
      call get_number('Initial Y-rot  [rad]  ',PHI0  , stat = ier)
      if (ier /= 0) goto 999
!
      call get_number('Initial Omega1 [rad/s]', omega10,   stat = ier)
      if (ier /= 0) goto 999
      call get_number('Initial Omega2 [rad/s]', omega20,  stat = ier)
      if (ier /= 0) goto 999
      call get_number('Initial Omega3 [rad/s]', omega30 , stat = ier)
      if (ier /= 0) goto 999
!
      call get_number('Initial Vx     [m/s]  ', vcx0,   stat = ier)
      if (ier /= 0) goto 999
      call get_number('Initial Vy     [m/s]  ', vcy0,   stat = ier)
      if (ier /= 0) goto 999
!      call get_number('Initial Omega3 [rad/s]', omega30 , stat = ier)
!      if (ier /= 0) goto 999
!
      call get_number('Friction coeff - static ', xmus,minv=zero,maxv=one,   stat = ier)
      if (ier /= 0) goto 999
      xmud=min(XMUd,xmus)
      call get_number('Friction coeff - dynamics ', xmud,minv=zero,maxv=xmus,   stat = ier)
      call get_number('Rolling resitance x [m]', xmurx,   stat = ier)
      call get_number('Rolling resitance y [m]', xmury,   stat = ier)
      call get_number('Boring  resitance z [m]', xmurz,   stat = ier)
!
      call get_number('End time       [s]    ', tend,   stat = ier)
      if (ier /= 0) goto 999
      call get_number('Print time step  [s]    ', tprint,  stat = ier)
      if (ier /= 0) goto 999

      prec = LOW
      call get_number('Integration precision [0,1]',prec,fmt='i4',minv=0,maxv=1,stat=ier)
      if (ier /= 0) goto 999
      if (prec == LOW) then
         reltol = 1.0e-5_8
      else
         reltol= 1.0e-6_8
      endif
      call get_number('RelTol          ', reltol,   stat = ier)
      if (ier /= 0) goto 999
      abstol = reltol
      call get_number('AbsTol          ', abstol,   stat = ier)
      if (ier /= 0) goto 999

      return
!
! Error exit---
!
999   continue
      if (ier /= 0) then
         call set_string(1,'*** Input error. By.')
         stop
      endif
!
      end subroutine input
      
