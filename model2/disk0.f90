      subroutine disk0
!
!  Modules used---
      use disk_data, only: g, r, hh, rho, xk12, xk22, &
      &  xmus, xmud, xmurx, xmury, xmurz, &
      &  mode, rolling, sliding, nout, theta_line_smooth
!
      use cdata
      implicit none
!            
!  Arguments---
!     NONE
!
!  FORTRAN functions called---
      intrinsic   abs, cos, sin, sign, sqrt
!
!  Function called---
!     NONE
!
!  Subroutines called---
!     NONE
!
!  Local parameters---
      real(8), parameter :: zero = 0.0_8
      real(8), parameter :: one  = 1.0_8
      real(8), parameter :: hpi  = 1.5707963267948966192313216916398_8
!
!  Local scalars---
      real(8) :: b1, b2, b3,  d
      real(8) :: abth, absi, dhmag, dsig, hmag, sig, u
!
!  Local arrays---
!     NONE
!
!  Executable statements---
!
!     sin and cos of angles
!
      sipsi = sin(psi)
      copsi = cos(psi)
      sith  = sin(theta)
      coth  = cos(theta)
  !    siphi = sin(phi)
   !   cophi = cos(phi)
      if (abs(theta) /= hpi) then
         tanth = sith/coth
      else
         write(*,*) '***error in disk0: theta = ',theta
         stop
      endif
!
!     Coordinates of contact point in (h,r)
!
      abth = abs(theta)
      if (theta_line_smooth > zero .and. abth < theta_line_smooth) then
         u    = theta/theta_line_smooth
         sig  = 1.5_8*u - 0.5_8*u**3
         dsig = (1.5_8 - 1.5_8*u**2)/theta_line_smooth
         absi = abs(sith)
         hmag = hh - rho*(one - absi)
         if (theta > zero) then
            dhmag = rho*coth
         else if (theta < zero) then
            dhmag = -rho*coth
         else
            dhmag = zero
         endif
         hp  = hmag*sig
         dhp = dhmag*sig + hmag*dsig
         rp  = r  - rho*(one - coth)
         drp = -rho*sith
      elseif (theta == zero) then ! this is special case
         hp = zero
         rp = r
      elseif (theta > zero .and. theta <= hpi) then
            hp = hh - rho*(one - sith)
            rp = r  - rho*(one - coth)
      else if (theta < zero .and. theta >= - hpi) then
            hp = -hh + rho*(one + sith)
            rp =   r - rho*(one - coth)
      else
!        This is another special case: theta = +/- hpi
!        'Contact point' is center of disk
         hp = sign(one,theta)*hh
         rp = zero
      endif
!
!     Coordinates of contact point in (y,z)
!
      yp  = - hp*coth + rp*sith
      zp  = -(hp*sith + rp*coth)
      zzc = -zp !<==================
      zzp = zero
!
      xxp = xxc - yp*sipsi
      yyp = yyc + yp*copsi
!
!     Derivatives of (hp,rp) to theta
!
      if (theta_line_smooth > zero .and. abth < theta_line_smooth) then
!        Derivatives were calculated with the regularized contact point above.
      else if (theta == zero) then
!        This is special case
         dhp = rho   !!!
         drp = zero
      else if (-hpi <= theta .and. theta <= hpi) then            
         dhp = rho*coth
         drp = -rho*sith
      else
!        This is special case: theta = +/- hpi
         dhp = sign(one,theta)
         drp = zero
      endif      
!
!     Derivative of yp to theta
!
      dyp = -dhp*coth + drp*sith - zp
!
!     Angular velocity in (x,y)
!
      omegax = omega1
      omegay = omega2*coth - omega3*sith
      omegaz = omega2*sith + omega3*coth
!
!     Contact moment factors
!
      xmx = zero
      xmy = zero
      xmz = zero
      if (omegax /= zero) xmx = - xmurx*omegax/abs(omegax)
      if (omegay /= zero) xmy = - xmury*omegay/abs(omegay)
      if (omegaz /= zero) xmz = - xmurz*omegaz/abs(omegaz)
!
      xm1 =   xmx
      xm2 =   xmy*coth + xmz*sith
      xm3 = - xmy*sith + xmz*coth
!
!     Velocity of center point and contact point. 
!
      if (mode == rolling) then
         vcx = rp*omega2 - hp*omega3
         vcy = zp*omega1
         vcz = -yp*omega1
         vpx = zero
         vpy = zero
         vpz = zero
         vp  = zero
      else if (mode == sliding) then
         vcz = -yp*omega1 
         vpx = vcx - rp*omega2 + hp*omega3
         vpy = vcy - zp*omega1
         vpz = vcz + yp*omega1   ! This must be zero
         vp  = sqrt(vpx**2 + vpy**2)
      endif
!
!     Friction force
!
      a  = xk22*omega2 - xk12*tanth*omega3
      b3 = g - omega1**2*dyp
!
      if (mode == sliding) then
         if (vp == zero) then
            if (nout == 0) then
               mode = rolling
               return
            endif
            write(*,*) '***error in disk0: vp == zero in sliding mode'
            stop
         endif
!
         xmux = -xmud*vpx/vp
         xmuy = -xmud*vpy/vp
!
         d = xk12 + yp*(yp + xm1 - xmuy*zp)
         if (d == zero) then
            write(*,*) '***error in disk0: xmuy*zp to large'
            stop
         endif
!
         fz = (xk12*b3 - yp*omega3*a)/d
!
         fx = xmux*fz
         fy = xmuy*fz
!
      else if (mode == rolling) then
!
         b1 = omega1*(omega2*drp - omega3*(dhp + zp/coth))
         b2 = omega1**2*yp + omega3*(rp*omega2 - hp*omega3)/coth
!
         d  = xk12 + yp**2 + zp**2 + xm1*yp
         fz = (-yp*a*omega3 + b3*(xk12 + zp**2) + b2*yp*zp)/d
!
         fy = (zp*((yp + xm1)*fz + a*omega3) + b2*xk12)/(xk12 + zp**2)
!
         fx = (rp*xm2*xk12 - hp*xm3*xk22)*fz + xk22*(b1*xk12 + hp*a*omega1)
         fx = fx/((rp**2 + xk22)*xk12 + hp**2*xk22) 
      endif
!
      end subroutine disk0
