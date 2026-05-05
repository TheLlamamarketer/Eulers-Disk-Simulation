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
      integer :: icmode
      real(8) :: phi_deg, psi_deg, theta_deg
      logical :: use_defaults
      character(8) :: cenv
!
!  Executable statements---
!
      call date_and_time( cdate, ctime)
      cdate(:) = cdate(7:8)//'/'//cdate(5:6)//'/'//cdate(1:4)
      ctime(:) = ctime(1:2)//':'//ctime(3:4)//':'//ctime(5:6)
!
!     Initial values are the original Euler's disk example geometry.
!
      r     = 37.55e-3_8
      h     = 12.80e-3_8
      rho   =  2.00e-3_8
      hh    =  H/2.0_8
      disk_density = 7792.2775363052142_8
!
      tstart = 0.0_8
      tend   = 13.83_8
!
!     Default initial values from Kessler 
!
      psi0   = ZERO
      theta0 = 1.0_8 
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
      xmurx_scale = 0.0001_8
      xmury_scale = 0.0008_8
      xmurz_scale = 0.0080_8
      call update_disk_properties()
!
!     DOPRI stuff
!
      reltol = 1.0E-8_8
      abstol = reltol
      tprint = 0.0005_8
      prec   = HIGH
      reltol = 1.0E-6_8
      abstol = reltol
      tout   = tstart
!
      call get_environment_variable('EDISK_DEFAULTS', cenv)
      use_defaults = trim(cenv) == '1'
      if (use_defaults) then
         call prop( r, h, rho, xk12, xk22)
         call update_disk_properties()
         return
      endif
!
!     Get values
!
      call get_number('Disk radius    [m]    ',r,   stat = ier)
      if (ier /= 0) goto 999      
      call get_number('Disk height    [m]    ',h ,  stat = ier)
      if (ier /= 0) goto 999
      hh = h/2.0_8
      if (hh /= zero) then
      call get_number('Disk filet     [m]    ',rho, minv = 0.0_8, maxv = hh, stat = ier)
      if (ier /= 0) goto 999
      else
         rho=zero
      endif
      call prop( r, h, rho, xk12, xk22)
      call get_number('Disk density [kg/m^3]', disk_density, &
     &   minv=1.0e-12_8, stat=ier)
      if (ier /= 0) goto 999
      call update_disk_properties()
!
      psi_deg = psi0*180.0_8/PI
      theta_deg = theta0*180.0_8/PI
      phi_deg = phi0*180.0_8/PI
      call get_number('Initial Z-rot  [deg]  ',psi_deg, stat = ier)
      if (ier /= 0) goto 999
      call get_number('Initial X-rot  [deg]  ',theta_deg, stat = ier)
      if (ier /= 0) goto 999
      call get_number('Initial Y-rot  [deg]  ',phi_deg, stat = ier)
      if (ier /= 0) goto 999
      psi0   = psi_deg*PI/180.0_8
      theta0 = theta_deg*PI/180.0_8
      phi0   = phi_deg*PI/180.0_8
!
      icmode = 0
      call get_number('Initial condition mode [0=manual,1=strike]', &
      &  icmode, fmt='i4', minv=0, maxv=1, stat=ier)
      if (ier /= 0) goto 999
!
      if (icmode == 1) then
         call strike_initial_condition(ier)
         if (ier /= 0) goto 999
      else
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
      endif
!      call get_number('Initial Omega3 [rad/s]', omega30 , stat = ier)
!      if (ier /= 0) goto 999
!
      call get_number('Friction coeff - static ', xmus,minv=zero,maxv=one,   stat = ier)
      if (ier /= 0) goto 999
      xmud=min(XMUd,xmus)
      call get_number('Friction coeff - dynamics ', xmud,minv=zero,maxv=xmus,   stat = ier)
      call get_number('Rolling resistance x/R [-]', xmurx_scale, &
     &   minv=zero, stat = ier)
      if (ier /= 0) goto 999
      call get_number('Rolling resistance y/R [-]', xmury_scale, &
     &   minv=zero, stat = ier)
      if (ier /= 0) goto 999
      call get_number('Boring resistance z/R [-]', xmurz_scale, &
     &   minv=zero, stat = ier)
      if (ier /= 0) goto 999
      call update_disk_properties()
!
      call get_number('End time       [s]    ', tend,   stat = ier)
      if (ier /= 0) goto 999
      call get_number('Print time step  [s]    ', tprint,  stat = ier)
      if (ier /= 0) goto 999

      prec = HIGH
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

      subroutine strike_initial_condition(ier)
!
!  Purpose---
!     Compute reproducible initial velocities from a simple pendulum strike.
!
      use disk_data
      use mui, only: get_number, set_string
!
      implicit none
!
      integer, intent(out) :: ier
!
      real(8) :: nxw, nyw, nzw, nx1, ny1, nz1, nx2, ny2, nz2
      real(8) :: tx, ty, tz, ax, ay, az, bx, by, bz
      real(8) :: denom, vwx, vwy, cpsi, spsi, cth, sth
      real(8) :: radial2
      real(8) :: direction_deg, pend_mass, pend_length, release_angle
      real(8) :: release_angle_deg, surface_angle_deg
      real(8) :: restitution, efficiency, direction
      real(8) :: surface_angle, surface_axis, surface_radius
      real(8) :: hp0, rp0, zp0
      integer :: surface, velocity_mode
!
      ier = 0
!
      pend_mass     = max(0.01_8, strike_mass)
      pend_length   = max(0.10_8, strike_length)
      release_angle = strike_release
      restitution   = strike_restitution
      efficiency    = strike_efficiency
      direction     = strike_direction
      surface        = strike_surface
      velocity_mode  = strike_velocity_mode
      if (strike_point(1) == ZERO .and. strike_point(2) == ZERO .and. &
      &   strike_point(3) == ZERO) then
         strike_point(1) = r
         strike_point(2) = ZERO
         strike_point(3) = ZERO
      endif
      surface_angle = ZERO
      radial2 = strike_point(1)**2 + strike_point(3)**2
      if (radial2 > ZERO) surface_angle = atan2(strike_point(3), strike_point(1))
      surface_axis = max(-hh, min(hh, strike_point(2)))
      surface_radius = min(r, sqrt(max(ZERO, radial2)))
      if (surface_radius == ZERO) surface_radius = r
      release_angle_deg = release_angle*180.0_8/PI
      direction_deg = direction*180.0_8/PI
      surface_angle_deg = surface_angle*180.0_8/PI
!
      call get_number('Pendulum mass [kg]', pend_mass, minv=1.0e-6_8, stat=ier)
      if (ier /= 0) return
      call get_number('Pendulum length [m]', pend_length, minv=1.0e-6_8, stat=ier)
      if (ier /= 0) return
      call get_number('Pendulum release angle [deg]', release_angle_deg, minv=ZERO, stat=ier)
      if (ier /= 0) return
      call get_number('Restitution coeff [0,1]', restitution, minv=ZERO, maxv=ONE, stat=ier)
      if (ier /= 0) return
      call get_number('Impact efficiency [0,1]', efficiency, minv=ZERO, maxv=ONE, stat=ier)
      if (ier /= 0) return
      call get_number('Strike direction angle [deg]', direction_deg, stat=ier)
      if (ier /= 0) return
      release_angle = release_angle_deg*PI/180.0_8
      direction = direction_deg*PI/180.0_8
      call get_number('Strike surface [0=rim,1=+face,2=-face]', surface, &
      &   fmt='i4', minv=0, maxv=2, stat=ier)
      if (ier /= 0) return
      if (surface == 0) then
         call get_number('Strike rim angle [deg]', surface_angle_deg, stat=ier)
         if (ier /= 0) return
         call get_number('Strike rim axial offset [m]', surface_axis, &
      &      minv=-hh, maxv=hh, stat=ier)
         if (ier /= 0) return
         surface_angle = surface_angle_deg*PI/180.0_8
         strike_point(1) = r*cos(surface_angle)
         strike_point(2) = surface_axis
         strike_point(3) = r*sin(surface_angle)
      else
         call get_number('Strike face radius [m]', surface_radius, &
      &      minv=ZERO, maxv=r, stat=ier)
         if (ier /= 0) return
         call get_number('Strike face angle [deg]', surface_angle_deg, stat=ier)
         if (ier /= 0) return
         surface_angle = surface_angle_deg*PI/180.0_8
         strike_point(1) = surface_radius*cos(surface_angle)
         if (surface == 1) then
            strike_point(2) = hh
         else
            strike_point(2) = -hh
         endif
         strike_point(3) = surface_radius*sin(surface_angle)
      endif
      call get_number('Post-impact center velocity [0=free,1=supported,2=rolling]', &
      &   velocity_mode, fmt='i4', minv=0, maxv=2, stat=ier)
      if (ier /= 0) return
!
      radial2 = strike_point(1)**2 + strike_point(3)**2
      if (radial2 > r**2) then
         call set_string(1,'*** Strike point is outside the disk radius.')
         ier = -1
         return
      endif
!
      strike_mass        = pend_mass
      strike_length      = pend_length
      strike_release     = release_angle
      strike_restitution = restitution
      strike_efficiency  = efficiency
      strike_direction   = direction
      strike_surface     = surface
      strike_velocity_mode = velocity_mode
!
!     Strike direction is horizontal in the world frame.
!
      nxw = cos(direction)
      nyw = sin(direction)
      nzw = ZERO
!
!     Convert strike direction from world to the disk dynamics frame.
!     The dynamics frame maps to world with Rz(psi0)*Rx(theta0).
!
      cpsi = cos(psi0)
      spsi = sin(psi0)
      cth  = cos(theta0)
      sth  = sin(theta0)
!
      nx1 =  cpsi*nxw + spsi*nyw
      ny1 = -spsi*nxw + cpsi*nyw
      nz1 =  nzw
!
      nx2 = nx1
      ny2 =  cth*ny1 + sth*nz1
      nz2 = -sth*ny1 + cth*nz1
!
!     Angular impulse direction: tau = r_contact x n.
!
      tx = strike_point(2)*nz2 - strike_point(3)*ny2
      ty = strike_point(3)*nx2 - strike_point(1)*nz2
      tz = strike_point(1)*ny2 - strike_point(2)*nx2
!
!     Effective mass denominator for a rigid impact against a rotating body.
!
      ax = tx/(xmass*xk12)
      ay = ty/(xmass*xk22)
      az = tz/(xmass*xk12)
!
      bx = ay*strike_point(3) - az*strike_point(2)
      by = az*strike_point(1) - ax*strike_point(3)
      bz = ax*strike_point(2) - ay*strike_point(1)
!
      denom = ONE/pend_mass + ONE/xmass + nx2*bx + ny2*by + nz2*bz
      if (denom <= ZERO) then
         call set_string(1,'*** Strike initializer: invalid effective mass.')
         ier = -1
         return
      endif
!
      strike_speed = sqrt(max(ZERO, &
     &   2.0_8*g*pend_length*(ONE - cos(release_angle))))
      strike_impulse = efficiency*(ONE + restitution)*strike_speed/denom
!
!     This first version assumes the disk starts from rest before impact.
!
      omega10 = strike_impulse*tx/(xmass*xk12)
      omega20 = strike_impulse*ty/(xmass*xk22)
      omega30 = strike_impulse*tz/(xmass*xk12)
      strike_torque_tip_spin = abs(tx)/(abs(tz) + 1.0e-30_8)
      strike_omega_tip_spin = abs(omega10)/(abs(omega30) + 1.0e-30_8)
!
      if (velocity_mode == 0) then
         vwx  = strike_impulse*nxw/xmass
         vwy  = strike_impulse*nyw/xmass
         vcx0 =  cpsi*vwx + spsi*vwy
         vcy0 = -spsi*vwx + cpsi*vwy
      else if (velocity_mode == 1) then
         vcx0 = ZERO
         vcy0 = ZERO
      else
         call strike_contact_geometry(theta0, hp0, rp0, zp0)
         vcx0 = rp0*omega20 - hp0*omega30
         vcy0 = zp0*omega10
      endif
      vcz0 = ZERO
!
      end subroutine strike_initial_condition

      subroutine strike_contact_geometry(theta_in, hp_out, rp_out, zp_out)
!
!  Purpose---
!     Contact geometry used for rolling-compatible strike velocity estimates.
!
      use disk_data
!
      implicit none
!
      real(8), intent(in)  :: theta_in
      real(8), intent(out) :: hp_out, rp_out, zp_out
!
      real(8) :: abth, absi, coth0, hmag, sig, sith0, u
!
      sith0 = sin(theta_in)
      coth0 = cos(theta_in)
      abth  = abs(theta_in)
!
      if (theta_line_smooth > ZERO .and. abth < theta_line_smooth) then
         u = theta_in/theta_line_smooth
         sig = 1.5_8*u - 0.5_8*u**3
         absi = abs(sith0)
         hmag = hh - rho*(ONE - absi)
         hp_out = hmag*sig
         rp_out = r - rho*(ONE - coth0)
      else if (theta_in == ZERO) then
         hp_out = ZERO
         rp_out = r
      else if (theta_in > ZERO .and. theta_in <= HPI) then
         hp_out = hh - rho*(ONE - sith0)
         rp_out = r - rho*(ONE - coth0)
      else if (theta_in < ZERO .and. theta_in >= -HPI) then
         hp_out = -hh + rho*(ONE + sith0)
         rp_out = r - rho*(ONE - coth0)
      else
         hp_out = sign(ONE, theta_in)*hh
         rp_out = ZERO
      endif
!
      zp_out = -(hp_out*sith0 + rp_out*coth0)
!
      end subroutine strike_contact_geometry
      
