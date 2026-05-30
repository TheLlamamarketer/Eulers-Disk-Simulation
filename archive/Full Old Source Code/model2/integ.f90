      subroutine integ
!
!  Purpose---
!     Integration subroutine
!
!  Modules used---
      use disk_data !, only: &
!      &  cresf, coutf, nout, iuout, iures, mode, rolling, sliding, &     
!      &  tstart, tend, tprint, abstol, reltol    
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
      integer           i, j, ierr, iu
      integer           idid
      integer           iout
      integer           itol
      integer           n
      double precision  rtol
      double precision  t
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
      write( iuout,'(4X,A,2X,E8.3)') 'Inertial moments X/Z    [m^2]',xk12
      write( iuout,'(4X,A,2X,E8.3)') 'Inertial moment Y       [m^2]',xk22
      write( iuout,'(4X,A,2X,F8.4)') 'Disk mass (not needed)  [kg] ',xmass
      write( iuout,'(4X,A,2X,F8.3)') 'Static friction         [-]  ',xmus
      write( iuout,'(4X,A,2X,F8.4)') 'Kinetics friction       [-]  ',xmud
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
      write( iuout,'(4X,A,2X,i8)') 'Initial motion               ',mode
!
      do i = 1, 2
         iu = 6
         if (i == 2) iu = iuout
	      write(iu,'(/2x,a)')         'dopri data'
	      write(iu,'( 4x,a,2x,i6)') 'precision (0=low,1=high) ',prec
	      write(iu,'( 4x,a,2x,f6.3)') 'start time        ',tstart
	      write(iu,'( 4x,a,2x,f6.3)') 'end   time        ',tend
	      write(iu,'( 4x,a,2x,f6.3)') 'print time        ',tprint
	      write(iu,'( 4x,a,2x,e9.3)') 'relative tolerance',reltol
	      write(iu,'( 4x,a,2x,e9.3)') 'absolute tolerance',abstol
      enddo
!
	   write(*,'(/x ,a)') 'start calculation'
!
!     output routine (and dense output) is used during integration
!
      iout=2
!
!     initial values and endpoint of integration
!
      call cpu_time(tcpus)
      t      = tstart 
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
!
!        dense output is used for all unknowns
!
         iwork(5) = n
         do i = 1, n
            iwork(20 + i) = i
         enddo      
!
         if (prec == LOW) then
         call DOPRI5( n, disk, t, y, tend, rtol, atol, itol, solout, iout,&
     &   work, lwork, iwork, liwork, rpar, ipar, idid)
         else if (prec == HIGH) then
         call DOP853( n, disk, t, y, tend, rtol, atol, itol, solout, iout,&
     &   work, lwork, iwork, liwork, rpar, ipar, idid)
         endif

         if (idid < 0 .or. idid == 1) exit
         do i = 1, 2
         iu = 6
         if (i == 2) iu = iuout
	      write(iu,'( 4x,a,t22,f8.3)') 'time',t
	      write(iu,'(/4x,a,t22,i8)')   'status code  ',idid
	      write(iu,'(/4x,a,t22,i8)')   'number of outputs ',nout
	      write(iu,'( 4x,a,t22,i8)')   'fcn               ',iwork(17)
	      write(iu,'( 4x,a,t22,i8)')   'step              ',iwork(18)
	      write(iu,'( 4x,a,t22,i8)')   'accept            ',iwork(19)
	      write(iu,'( 4x,a,t22,i8)')   'reject            ',iwork(20)
         enddo
!     
         t = tstar !out   ! last output is new start  
!
         idid = 0
         do i = 1, 2
            iu = 6
            if (i == 2) iu = iuout
	         write(iu,'( 4x,a,2x,f6.3,2x,a,a)') 'change mode at',t,' mode=',cmode(mode)
         enddo
!
         if (bstop) exit

      enddo
      call cpu_time(tcpue)

!
      close(iures)
!
      do i = 1, 2
         iu = 6
         if (i == 2) iu = iuout
	      write(iu,'( 4x,a,t22,f8.3)') 'end time',t
	      write(iu,'(/4x,a,t22,i8)')   'exit status code  ',idid
	      write(iu,'( 4x,a,t22,f9.3)') 'CPU time',tcpue-tcpus
	      write(iu,'(/4x,a,t22,i8)')   'number of outputs ',nout
	      write(iu,'( 4x,a,t22,i8)')   'fcn               ',iwork(17)
	      write(iu,'( 4x,a,t22,i8)')   'step              ',iwork(18)
	      write(iu,'( 4x,a,t22,i8)')   'accept            ',iwork(19)
	      write(iu,'( 4x,a,t22,i8)')   'reject            ',iwork(20)
         write(iu,'( 4x,a,t22,d8.2)') 'relative tolearnce',rtol
!	      write(iu,'( 4x,a,2x,e9.3)') 'absolute error',abserr
         write(iu,'(4x,a)') 'results are saved on file '//cresf 
         write(iu,'(2x,a)') 'end' 
      enddo
!
      close(iuout)
!      
      end subroutine integ
