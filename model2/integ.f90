      subroutine integ
!
!  Purpose---
!     Integration subroutine
!
!  Modules used---
      use disk_data !, only: &
!      &  cresf, coutf, nout, iuout, iures, mode, rolling, sliding, &     
!      &  tstart, tend, tprint, abstol, reltol    
      use cdata, only: fx, fy, vp, zzc, vcx, vcy, vcz
!
      implicit none
!
!  Subroutines called---
      external disk, solout
!
!  Parameters---
      integer, parameter :: neqn   = 12
      integer, parameter :: nrdens = neqn
!      integer, parameter :: lwork  = 8*neqn + 5*nrdens + 20
      integer, parameter :: lwork  = 11*neqn + 8*nrdens + 20
      integer, parameter :: liwork = nrdens + 20
!
!  Scalars---
      double precision  atol
      integer           i, j, ierr
      integer           idid
      integer           iout
      integer           itol
      integer           n
      integer           stuck_events
      double precision  rtol
      double precision  t
      double precision  force_mag
      double precision  initial_pot_energy
      double precision  initial_rot_energy
      double precision  initial_total_energy
      double precision  initial_trans_energy
      double precision  last_event_t
      double precision  slip_seed
      double precision  stuck_tol
!
!  Arrays---
      integer           ipar(1)           ! dummy  
      integer           iwork(liwork)     
      double precision  rpar(2)           ! dummy
      double precision  y(neqn)
      double precision  work( lwork)
!
!  Executable statements---
!
! 
      open ( unit = iuout, file = coutf, iostat = ierr, &
     &    status = 'unknown')
	   if (ierr .ne. 0) then
	      write(*,*) ' *** integ: IO error #',ierr
	      stop
      endif
!
      open( unit = iures, file = cresf, status = 'unknown', iostat = ierr)
      if (ierr /= 0) then
         write(*,*) ' *** integ: IO error #',ierr
         stop
      endif
!
      y(1)  = psi0
      y(2)  = theta0
      y(3)  = phi0
      y(4)  = omega10
      y(5)  = omega20
      y(6)  = omega30
      y(7)  = xxc0
      y(8)  = yyc0
      y(9)  = vcx0
      y(10) = vcy0
!
      mode = sliding ! <=== assume
      call disk( 10, tstart, y, work, rpar, ipar)
      initial_trans_energy = 0.5d0*xmass*(vcx*vcx + vcy*vcy + vcz*vcz)
      initial_rot_energy = 0.5d0*xmass*(xk12*(y(4)*y(4) + y(6)*y(6)) &
      &                  + xk22*y(5)*y(5))
      initial_pot_energy = xmass*g*zzc
      initial_total_energy = initial_trans_energy + initial_rot_energy &
      &                    + initial_pot_energy
!
!     Write report file
!
      write( iuout,'(2X,A)')         'Euler''s Disk Simulation '
      write( iuout,'(2X,A)')         cvers
      write( iuout,'(4X,A)')         'Date: '//CDATE
      write( iuout,'(4X,A)')         'Time: '//CTIME
      write( iuout,'(4X,A)')         '---------------------------------'
      write( iuout,'(4X,A,2X,F8.4)') 'Disk radius             [m]  ',r
      write( iuout,'(4X,A,2X,F8.4)') 'Disk height             [m]  ',h
      write( iuout,'(4X,A,2X,F8.4)') 'Disk half height        [m]  ',hh
      write( iuout,'(4X,A,2X,F8.4)') 'Disk filet radius       [m]  ',rho
      write( iuout,'(4X,A,2X,E10.3)') 'Disk volume             [m^3]', &
     &   disk_volume(r,h,rho)
      write( iuout,'(4X,A,2X,F10.2)') 'Disk density          [kg/m3]', &
     &   disk_density
      write( iuout,'(4X,A,2X,E8.3)') 'Inertial moments X/Z    [m^2]',xk12
      write( iuout,'(4X,A,2X,E8.3)') 'Inertial moment Y       [m^2]',xk22
      write( iuout,'(4X,A,2X,F8.4)') 'Disk mass               [kg] ',xmass
      write( iuout,'(4X,A,2X,F8.3)') 'Static friction         [-]  ',xmus
      write( iuout,'(4X,A,2X,F8.4)') 'Kinetics friction       [-]  ',xmud
      write( iuout,'(4X,A,2X,E8.3)') 'Rolling friction X/R    [-]  ',xmurx_scale
      write( iuout,'(4X,A,2X,E8.3)') 'Rolling friction y/R    [-]  ',xmury_scale
      write( iuout,'(4X,A,2X,E8.3)') 'Boring  friction z/R    [-]  ',xmurz_scale
      write( iuout,'(4X,A,2X,E8.3)') 'Rolling friction X-dir  [m]  ',xmurx
      write( iuout,'(4X,A,2X,E8.3)') 'Rolling friction y-dir  [m]  ',xmury
      write( iuout,'(4X,A,2X,E8.3)') 'Boring  friction        [m]  ',xmurz
!
      write( iuout,'(4X,A,2X,F8.4)') 'Initial Psi             [rad]',y(1)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial Theta           [rad]',y(2)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial Phi             [rad]',y(3) 
      write( iuout,'(4X,A,2X,F8.4)') 'Initial OmegaX          [r/s]',y(4)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial OmegaY          [r/s]',y(5)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial OmegaZ          [r/s]',y(6)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial XC              [m]  ',y(7)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial YC              [m]  ',y(8)
!      write( iuout,'(4X,A,2X,F8.4)') 'Initial ZC (calculated) [m]  ',Y(9)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial VXC             [m/s]',y(9)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial VYC             [m/s]',y(10)
      write( iuout,'(4X,A,2X,F8.4)') 'Initial contact slip    [m/s]',vp
      write( iuout,'(4X,A,2X,E10.3)') 'Initial transl. energy  [J]  ', &
     &   initial_trans_energy
      write( iuout,'(4X,A,2X,E10.3)') 'Initial rot. energy     [J]  ', &
     &   initial_rot_energy
      write( iuout,'(4X,A,2X,E10.3)') 'Initial potential energy[J]  ', &
     &   initial_pot_energy
      write( iuout,'(4X,A,2X,E10.3)') 'Initial total energy    [J]  ', &
     &   initial_total_energy
      write( iuout,'(4X,A,2X,E10.3)') 'Energy stop excess      [J]  ', &
     &   energy_stop_tol
      if (strike_count > 0) then
         if (strike_count == 2) then
            write( iuout,'(4X,A)') &
     &         'Initial condition mode: double pendulum strike'
         else
            write( iuout,'(4X,A)') 'Initial condition mode: pendulum strike'
         endif
         write( iuout,'(4X,A,2X,F8.4)') 'Rod release theta      [rad]', &
     &      strike_release_angle
         write( iuout,'(4X,A,2X,F8.4)') 'Rod impact theta       [rad]', &
     &      strike_impact_angle
         write( iuout,'(4X,A,2X,F8.4)') 'Rod effective mass     [kg] ', &
     &      strike_effective_mass
         write( iuout,'(4X,A,2X,F8.4)') 'Restitution coeff      [-]  ',strike_restitution
         write( iuout,'(4X,A,2X,F8.4)') 'Impact efficiency      [-]  ',strike_efficiency
         write( iuout,'(4X,A,2X,F8.4)') 'Strike direction       [rad]',strike_direction
         write( iuout,'(4X,A,2X,I4)') 'Strike surface mode         ',strike_surface
         write( iuout,'(4X,A,2X,I4)') 'Post-impact velocity mode   ', &
     &      strike_velocity_mode
         write( iuout,'(4X,A,3(2X,F9.4))') 'Strike point body [m]       ', &
     &      strike_point(1),strike_point(2),strike_point(3)
         write( iuout,'(4X,A,2X,F8.4)') 'Rod impact speed       [m/s]',strike_speed
         write( iuout,'(4X,A,2X,E10.3)') 'Impact impulse         [Ns] ',strike_impulse
         if (strike_count == 2) then
            write( iuout,'(4X,A,2X,F8.4)') &
     &         'Rod 2 release theta    [rad]',strike2_release_angle
            write( iuout,'(4X,A,2X,F8.4)') &
     &         'Rod 2 impact theta     [rad]',strike2_impact_angle
            write( iuout,'(4X,A,2X,F8.4)') &
     &         'Rod 2 effective mass   [kg] ',strike2_effective_mass
            write( iuout,'(4X,A,2X,F8.4)') &
     &         'Restitution 2 coeff    [-]  ',strike2_restitution
            write( iuout,'(4X,A,2X,F8.4)') &
     &         'Impact 2 efficiency    [-]  ',strike2_efficiency
            write( iuout,'(4X,A,2X,F8.4)') &
     &         'Strike 2 direction     [rad]',strike2_direction
            write( iuout,'(4X,A,2X,I4)') &
     &         'Strike 2 surface mode       ',strike2_surface
            write( iuout,'(4X,A,3(2X,F9.4))') &
     &         'Strike point 2 body [m]     ', &
     &         strike2_point(1),strike2_point(2),strike2_point(3)
            write( iuout,'(4X,A,2X,F8.4)') &
     &         'Rod 2 impact speed     [m/s]',strike2_speed
            write( iuout,'(4X,A,2X,E10.3)') &
     &         'Impact 2 impulse       [Ns] ',strike2_impulse
         endif
         write( iuout,'(4X,A,2X,F8.4)') 'Strike torque wobble/axis [-]', &
     &      strike_torque_tip_spin
         write( iuout,'(4X,A,2X,F8.4)') 'Initial omega wobble/axis [-]', &
     &      strike_omega_tip_spin
         if (strike_omega_tip_spin > 0.5_8) then
            write( iuout,'(4X,A)') &
     &         'Launch warning: little axis spin; expect orbiting/flop/chatter.'
         else if (strike_omega_tip_spin > 0.25_8) then
            write( iuout,'(4X,A)') &
     &         'Launch note: mixed axis spin and wobble; near-flat motion likely.'
         else
            write( iuout,'(4X,A)') &
     &         'Launch note: axis-spin-dominant impulse.'
         endif
      else
         write( iuout,'(4X,A)') 'Initial condition mode: manual'
      endif
      write( iuout,'(4X,A,2X,i8)') 'Initial motion               ',mode
!
	   write(iuout,'(/2x,a)')         'dopri data'
	   write(iuout,'( 4x,a)') 'precision             high'
	   write(iuout,'( 4x,a,2x,f9.3)') 'start time        ',tstart
	   write(iuout,'( 4x,a,2x,f9.3)') 'end   time        ',tend
	   write(iuout,'( 4x,a,2x,f9.3)') 'print time        ',tprint
	   write(iuout,'( 4x,a,2x,e9.3)') 'relative tolerance',reltol
	   write(iuout,'( 4x,a,2x,e9.3)') 'absolute tolerance',abstol
!
	   write(*,'(/x,a)') 'Generating animation data...'
!
!     output routine (and dense output) is used during integration
!
      iout=2
!
!     initial values and endpoint of integration
!
      call cpu_time(tcpus)
      t      = tstart 
      stuck_events = 0
      last_event_t = tstart - 1.0d0
!
!     call of the subroutine dopri5   
!
      do while (t <= tend )
!
         if (mode == rolling) then
            n=8
         else if (mode == sliding) then
            n=10
         endif
!
!        required (relative and absolute) tolerance
!
         itol  = 0
         rtol  = reltol
         atol  = abstol
!
!        default values for parameters
!
          do i = 1,20
             iwork(i) = 0
             work(i)  = 0.0d0  
          enddo
          iwork(1) = 100*100000 !-nout
          iwork(3) = iuout
!
!        dense output is used for all unknowns
!
         iwork(5) = n
         do i = 1, n
            iwork(20 + i) = i
         enddo      
!
         call DOP853( n, disk, t, y, tend, rtol, atol, itol, solout, iout,&
     &   work, lwork, iwork, liwork, rpar, ipar, idid)

         if (idid < 0 .or. idid == 1) exit
	      write(iuout,'( 4x,a,t22,f8.3)') 'time',t
	      write(iuout,'(/4x,a,t22,i12)')   'status code  ',idid
	      write(iuout,'(/4x,a,t22,i12)')   'number of outputs ',nout
	      write(iuout,'( 4x,a,t22,i12)')   'fcn               ',iwork(17)
	      write(iuout,'( 4x,a,t22,i12)')   'step              ',iwork(18)
	      write(iuout,'( 4x,a,t22,i12)')   'accept            ',iwork(19)
	      write(iuout,'( 4x,a,t22,i12)')   'reject            ',iwork(20)
!     
         stuck_tol = max(abstol, 1.0d-12)
         if (abs(tstar - t) <= stuck_tol .and. &
     &       abs(tstar - last_event_t) <= stuck_tol) then
            stuck_events = stuck_events + 1
         else
            stuck_events = 0
         endif
         last_event_t = tstar
         if (stuck_events > 8) then
            write(*,'(x,a,f8.3,a)') &
     &         'Stopped at t=',tstar, &
     &         ' s; repeated zero-time mode changes.'
            write(iuout,'(4x,a,t22,f8.3)') 'zero-time stop',tstar
            idid = -4
            bstop = .true.
            exit
         endif
!
         t = tstar !out   ! last output is new start  
         if (mode == sliding) then
            y(1) = psi0
            y(2) = theta0
            y(3) = phi0
            y(4) = omega10
            y(5) = omega20
            y(6) = omega30
            y(7) = xxc0
            y(8) = yyc0
!           Start a new sliding segment outside the unresolved microslip
!           band used by the regularized kinetic friction law.
            slip_seed = max(10000.0d0*abstol, 5.0d0*slip_regularization)
            force_mag = sqrt(fx*fx + fy*fy)
            if (force_mag > 0.0d0) then
               y(9)  = vcx0 - slip_seed*fx/force_mag
               y(10) = vcy0 - slip_seed*fy/force_mag
            else
               y(9)  = vcx0
               y(10) = vcy0
            endif
         else
            y(9)  = vcx0
            y(10) = vcy0
         endif
!
         idid = 0
         if (.not. bstop) then
	         write(iuout,'( 4x,a,2x,f6.3,2x,a,a)') 'change mode at',t,' mode=',cmode(mode)
         endif
!
         if (bstop) exit

      enddo
      call cpu_time(tcpue)

!
      close(iures)
!
      write(*,*)
      if (idid < 0) then
         write(*,'(x,a,f8.3,a,i0,a)') 'Stopped at t=',t,' s; solver status ',idid,'.'
      endif
      write(*,'(x,a)') 'Saved animat.txt, result.txt, and report.txt.'
      write(iuout,'( 4x,a,t22,f8.3)') 'end time',t
      write(iuout,'(/4x,a,t22,i12)')   'exit status code  ',idid
      write(iuout,'( 4x,a,t22,f9.3)') 'CPU time',tcpue-tcpus
      write(iuout,'(/4x,a,t22,i12)')   'number of outputs ',nout
      write(iuout,'( 4x,a,t22,i12)')   'fcn               ',iwork(17)
      write(iuout,'( 4x,a,t22,i12)')   'step              ',iwork(18)
      write(iuout,'( 4x,a,t22,i12)')   'accept            ',iwork(19)
      write(iuout,'( 4x,a,t22,i12)')   'reject            ',iwork(20)
      write(iuout,'( 4x,a,t22,d8.2)') 'relative tolearnce',rtol
!	      write(iu,'( 4x,a,2x,e9.3)') 'absolute error',abserr
      write(iuout,'(4x,a)') 'results are saved on file '//cresf
      write(iuout,'(2x,a)') 'end'
!
      close(iuout)
!      
      end subroutine integ
