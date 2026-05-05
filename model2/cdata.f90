      module cdata
!
!  Data used in disk, disk0 and solout
!
      implicit none
      public
!
      real(8) :: xxc, yyc, zzc            ! COG global position
      real(8) :: vcx, vcy, vcz            ! COG velocity
      real(8) :: xxp, yyp, zzp            ! contact global point position
      real(8) :: vpx, vpy, vpz            ! contact point velocity
      real(8) :: psi, theta, phi          ! orientation angles
      real(8) :: fx, fy, fz               ! contact force
      real(8) :: xmx, xmy, xmz            ! contact moment in (1)
      real(8) :: xm1, xm2, xm3            ! contact moment in (2)
      real(8) :: xmux, xmuy               ! coeff of frictionin x,y - dir
      real(8) :: omega1, omega2, omega3   ! angular velocity in (2)
      real(8) :: omegax, omegay, omegaz   ! angular velocity in (1)
      real(8) :: rp, hp, yp, zp           ! local coordinates of contact point
      real(8) :: drp, dhp, dyp            ! derivatives of coordinates to theta
      real(8) :: vp                       ! contact point velocity
!
      real(8) :: sipsi, copsi, sith, coth ! sin and cos of psi and theta
      real(8) :: tanth, a
!
      integer, parameter :: ndeg = 2
      real(8) :: p(0:ndeg)
!
      end module cdata