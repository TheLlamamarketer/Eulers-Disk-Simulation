      module disk_data
!
! Purpose---
!     Disk rolling on a horizontal surface
!
!  Modules used---
!     NONE
!
      implicit none
      private
!
!  Parameters---
      real(8), public, parameter :: ZERO = 0.0_8
      real(8), public, parameter :: ONE  = 1.0_8
      real(8), public, parameter :: PI     = 3.1415926535897932384626433832795_8
      real(8), public, parameter :: TWOPI  = 2.0_8*PI
      real(8), public, parameter :: HPI    = PI/2.0_8
!
      real(8), public, parameter :: g = 9.8067_8  ! gravity acceleration [m/s^2]
      real(8), public, parameter :: physical_pend_mass = 0.39522465_8
      real(8), public, parameter :: physical_pend_com = 0.3605_8
      real(8), public, parameter :: physical_pend_contact = 0.7375_8
      real(8), public, parameter :: physical_pend_inertia_cm = 0.017704504_8
      real(8), public, parameter :: physical_pend_inertia_pivot = &
     &   physical_pend_inertia_cm + physical_pend_mass*physical_pend_com**2
      integer, public, parameter :: rolling = 1
      integer, public, parameter :: sliding = 2
      integer, public, parameter :: ROLL = 3
      integer, public, parameter :: SLIDE = 4
!
      integer, public, parameter :: LOW = 0
      integer, public, parameter :: HIGH = 1
!
      character(*), public, parameter :: cvers = 'M.Batista/UL FPP  Version 0.04'
!
      character(*), public, parameter :: cresf = 'result.txt'
      character(*), public, parameter :: coutf = 'report.txt'
      character(*), public, parameter :: cgraf = 'animat.txt' ! animation file
      integer,      public, parameter :: iuout  = 8
      integer,      public, parameter :: iures  = 9
      character(7), public, parameter ::  cmode(2) =(/'rolling','sliding'/)
      public :: disk_volume, update_disk_properties

!
!  Variables---
      real(8), public :: r = 37.55e-3_8      ! disk radius [m]
      real(8), public :: h = 12.80e-3_8      ! disk height [m]
      real(8), public :: hh                  ! disk half height [m]
      real(8), public :: rho = 2.00e-3_8     ! fillet radius [m]
      real(8), public :: disk_density = 7792.2775363052142_8 ! density [kg/m^3]
      real(8), public :: xmass = 0.4387_8    ! disk mass [kg]
      real(8), public :: xk12, xk22          ! radii of gyration [m^2]
!
      integer, public :: mode                ! disk moving mode
!
      real(8), public :: xmus                ! static friction coeff. 
      real(8), public :: xmud                ! dynamics friction coeff.
!
      real(8), public :: xmurx               ! rolling friction coeff. in x-dir
      real(8), public :: xmury               ! rolling friction coeff. in y-dir
      real(8), public :: xmurz               ! rolling friction coeff. in z-dir
      real(8), public :: xmurx_scale = 1.0e-4_8 ! rolling resistance x/R [-]
      real(8), public :: xmury_scale = 8.0e-4_8 ! rolling resistance y/R [-]
      real(8), public :: xmurz_scale = 8.0e-3_8 ! boring resistance z/R [-]
!
      integer, public :: nout
      real(8), public :: tout   = 0.0_8
      real(8), public :: tprint = 0.001_8
      real(8), public :: tstart
      real(8), public :: tend
      real(8), public :: abstol 
      real(8), public :: reltol
      integer, public :: prec = HIGH
      real(4), public :: tcpus
      real(4), public :: tcpue
      real(8), public :: tstar
      logical, public :: bstop = .false.
      real(8), public :: theta_line_smooth = 2.0e-2_8
      real(8), public :: theta_flat_stop_tol = 2.0e-4_8
      real(8), public :: energy_stop_tol = 3.0e-4_8
      real(8), public :: slip_regularization = 1.0e-3_8
!
      character(10), public :: cdate   ! curent date
      character(12), public :: ctime   ! current time
!
      real(8), public :: psi0, theta0, phi0
      real(8), public :: xxc0, yyc0, zzc0
      real(8), public :: vcx0, vcy0, vcz0
      real(8), public :: omega10, omega20, omega30
!
      integer, public :: strike_count = 0
      real(8), public :: strike_effective_mass = ZERO
      real(8), public :: strike_release_angle = ZERO
      real(8), public :: strike_impact_angle = ZERO
      real(8), public :: strike_restitution = ZERO
      real(8), public :: strike_efficiency = ONE
      real(8), public :: strike_direction = ZERO
      real(8), public :: strike_point(3) = (/ZERO, ZERO, ZERO/)
      integer, public :: strike_surface = 0
      integer, public :: strike_velocity_mode = 1
      real(8), public :: strike_speed = ZERO
      real(8), public :: strike_impulse = ZERO
      real(8), public :: strike2_effective_mass = ZERO
      real(8), public :: strike2_release_angle = ZERO
      real(8), public :: strike2_impact_angle = ZERO
      real(8), public :: strike2_restitution = ZERO
      real(8), public :: strike2_efficiency = ONE
      real(8), public :: strike2_direction = ZERO
      real(8), public :: strike2_point(3) = (/ZERO, ZERO, ZERO/)
      integer, public :: strike2_surface = 0
      real(8), public :: strike2_speed = ZERO
      real(8), public :: strike2_impulse = ZERO
      real(8), public :: strike_torque_tip_spin = ZERO
      real(8), public :: strike_omega_tip_spin = ZERO
!
      contains

      real(8) function disk_volume(radius, height, fillet) result(volume)
!
!  Purpose---
!     Approximate volume of the rounded disk used by prop.f.  For zero fillet
!     this reduces to the ordinary cylinder volume pi*r^2*h.
!
      implicit none
!
      real(8), intent(in) :: radius, height, fillet
      real(8) :: f
!
      if (radius <= ZERO .or. height <= ZERO) then
         volume = ZERO
         return
      endif
!
      f = max(ZERO, min(fillet, height/2.0_8, radius))
      volume = PI*(height*radius**2 + PI*radius*f**2 - PI*f**3 &
     &      + (10.0_8/3.0_8)*f**3 - 4.0_8*radius*f**2)
      if (volume <= ZERO) volume = PI*radius**2*height
!
      end function disk_volume

      subroutine update_disk_properties()
!
!  Purpose---
!     Keep geometry-derived mass and resistance lengths synchronized with the
!     currently selected material/size inputs.
!
      implicit none
!
      xmass = disk_density*disk_volume(r, h, rho)
      xmurx = xmurx_scale*r
      xmury = xmury_scale*r
      xmurz = xmurz_scale*r
!
      end subroutine update_disk_properties

!
      end module disk_data
