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
      real(8), public, parameter :: g = 9.81_8  ! gravity acceleration [m/s^2]
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

!
!  Variables---
      real(8), public :: r = 37.55e-3_8      ! disk radius [m]
      real(8), public :: h = 12.80e-3_8      ! disk height [m]
      real(8), public :: hh                  ! disk half height [m]
      real(8), public :: rho = 3.00e-3_8     ! fillet radius [m]
      real(8), public :: xmass = 0.4387_8    ! disk mass [m]
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
!
      integer, public :: nout
      real(8), public :: tout   = 0.0_8
      real(8), public :: tprint = 0.001_8
      real(8), public :: tstart
      real(8), public :: tend
      real(8), public :: abstol 
      real(8), public :: reltol
      integer, public :: prec = LOW
      real(4), public :: tcpus
      real(4), public :: tcpue
      real(8), public :: tstar
      logical, public :: bstop = .false.
!
      character(10), public :: cdate   ! curent date
      character(12), public :: ctime   ! current time
!
      real(8), public :: psi0, theta0, phi0
      real(8), public :: xxc0, yyc0, zzc0
      real(8), public :: vcx0, vcy0, vcz0
      real(8), public :: omega10, omega20, omega30
!
      end module disk_data