      subroutine solout ( nr, told, t, x, n, con, icomp, nd, rpar, ipar, irtrn)
!
!  Purpose---
!     Print solution after every successful integration step
!
!  Modules used---
      use disk_data
      use cdata
!
      implicit none
!            
!  Arguments---
      integer, intent(in)  :: nr          ! number of steps so far
      real(8), intent(in)  :: told        ! preceeding time
      real(8), intent(in)  :: t           ! current time
      integer, intent(in)  :: n           ! number of equations
      real(8), intent(in)  :: x(*)        ! solution at told
      integer, intent(in)  :: nd          ! number of solutions
      real(8), intent(in)  :: con(*)      ! coefficients of interpolation
      integer, intent(in)  :: icomp(*)    ! solutions indices
      real(8), intent(in)  :: rpar(*)     ! dummy
      integer, intent(in)  :: ipar(*)     ! dummy   
      integer, intent(out) :: irtrn       ! integration interruption flag 
!
!  FORTRAN functions called---
      intrinsic   atan2
!
!  Functions called---
      interface
         real(8) function CONTD5( i, t, con, icomp, nd)
            integer, intent(in) :: i       ! i-th component of solution at t
            real(8), intent(in) :: t         
            integer, intent(in) :: nd
            real(8), intent(in) :: con(*)
            integer, intent(in) :: icomp(*)
         end function
      end interface
!
      interface
         real(8) function CONTD8( i, t, con, icomp, nd)
            integer, intent(in) :: i         ! i-th component of solution at t
            real(8), intent(in) :: t         
            integer, intent(in) :: nd
            real(8), intent(in) :: con(*)
            integer, intent(in) :: icomp(*)
         end function
      end interface
!
      interface
         real(8) function zeroin(ax,bx,f,tol)
            real(8),intent(in) :: ax,bx, tol
            interface
               real(8) function f(x)
                  real(8), intent(in) :: x
               end function
            end interface
         end function
      end interface
!
      interface
         real(8) function ztime(t)
            real(8),intent(in) :: t
         end function
      end interface
!
!  Local parameters---
	   character(6), parameter :: CHEAD(31) = (/&
      &  'TNOW  ', &
      &  'PSI   ', 'THETA ', 'PHI   ', &
      &  'OMEGA1', 'OMEGA2', 'OMEGA3', &
      &  'VCX   ', 'VCY   ', 'VCZ   ', &     
      &  'XC    ', 'YC    ', 'ZC    ', &
      &  'XP    ', 'YP    ', 'ZP    ', &
      &  'VPX   ', 'VPY   ', 'VPZ   ', &
      &  'OMEGAX', 'OMEGAY', 'OMEGAZ', &
      &  'FX/WGT', 'FY/WGT', 'FZ/WGT', &
      &  'FN/WGT', 'FT/WGT', 'XMU   ', &
      &  'VS    ', 'ALPHA ', 'MODE  '/)
!
      integer, parameter :: ksize = 3
!  Local scalars---
      integer, save :: kstart = 1, kend = 0
      integer, save :: last_percent = -1
      integer :: i, ier, k, j1, j2, j3
      integer :: percent, filled, width
      real(8) :: xmu, ft, fn, alpha, a0, a1, a2, dd, ttt
      real(8) :: excess_energy, kinetic_energy, potential_energy
      real(8) :: theta_stop
      logical :: binit = .false.
!
!  Local array---
      real(8) :: xnow(12)
      real(8), save :: vvv(ksize), fff(ksize) , thh(ksize) ! queue
!
! Executable statements---
!
      irtrn = 0
!
      if (.not. binit) then
	      write( iures,'(6X,31(A,12X))') (CHEAD(i),i=1,31)
         nout=0
         binit = .true.
      endif
!         
      k = 0
      tstar = t
!
      do while (tstar >= tout) 
!
         k = k + 1
         if (nr == 1) then
!           First step
            do i = 1, nd
               xnow(i) = x(icomp(i))
            enddo
         else
            do i = 1, nd
               if (prec == LOW) then
                  xnow(i) = CONTD5( i, tout, con, icomp, nd)
               else if (prec == HIGH) then
                  xnow(i) = CONTD8( i, tout, con, icomp, nd)
               else
               endif
            enddo
         endif
!         
         psi    = xnow(1)
         theta  = xnow(2)
         phi    = xnow(3)
         omega1 = xnow(4)
         omega2 = xnow(5)
         omega3 = xnow(6)
         xxc    = xnow(7)
         yyc    = xnow(8)
!
         if (mode == sliding) then
            vcx   = xnow(9)
            vcy   = xnow(10)
         endif
!
!        Calculate velocities and forces
!
         call disk0
!
         if (irtrn < 0) then
            psi0    = psi
            theta0  = theta
            phi0    = phi
            omega10 = omega1
            omega20 = omega2
            omega30 = omega3
            xxc0    = xxc
            yyc0    = yyc
            vcx0    = vcx
            vcy0    = vcy     
            if (irtrn /= -3) then
               if (mode == sliding) then
                  mode  = rolling
               else if (mode == rolling) then
                  mode = sliding
               endif
            endif
              tout = ttt 
            return
         endif
!
         fn = fz
         if (fn <= 0) then
            write(*,*) ' Lost contact at ',tout
            write(iuout,'(4x,a,t22,f8.3)') 'lost contact',tout
            tstar = tout
            irtrn = -3
            bstop = .true.
            return
         endif
!
         ft    = sqrt(fx**2 + fy**2)
         xmu   = ft/fn
         alpha = atan2( fy, fx)
!
         kinetic_energy = 0.5_8*xmass*(vcx*vcx + vcy*vcy + vcz*vcz) &
     &      + 0.5_8*xmass*(xk12*(omega1*omega1 + omega3*omega3) &
     &      + xk22*omega2*omega2)
         potential_energy = xmass*g*max(0.0_8, zzc - hh)
         excess_energy = kinetic_energy + potential_energy
         if (energy_stop_tol > zero .and. excess_energy <= energy_stop_tol) then
            write(*,*) ' Energy stop at ',tout
            write(iuout,'(4x,a,t22,f8.3)') 'energy stop',tout
            tstar = tout
            irtrn = -3
            bstop = .true.
            return
         endif
!
!        Add results to queue
!
         kend = kend + 1
         if ( kend   > ksize)  kend   = 1
         if ( kend  == kstart) kstart = kend + 1
         if ( kstart > ksize)  kstart = 1
!  
         vvv(kend) = vp
         fff(kend) = ft - xmus*fn
         thh(kend) = theta
!
!        Queue is empty at the begining...so fill it
!
         if (nr == 1) then
            do i = kstart, ksize
               vvv(i) = vvv(kend)
               fff(i) = fff(kend)
               thh(i) = thh(kend)
            enddo
         endif
!
         theta_stop = max(abstol, theta_flat_stop_tol)
         if (theta_line_smooth <= zero .and. abs(thh(kend)) < abstol) then
!              Calculate slap  time
!
               j1 = kstart
               j2 = j1 + 1
               if (j2 > ksize) j2 = 1
               j3 = kend
!
               p(0) = thh(j2)
               p(1) = (thh(j3) - thh(j1))/(2.0_8*tprint)
               p(2) = (thh(j3) - 2.0_8*thh(j2) + thh(j1))/(2.0_8*tprint**2) 
               ttt  = zeroin( zero, tprint, ztime, abstol)
!
!
               if (ttt >= zero .and. ttt <= tprint) then
                  tstar = tout + ttt - tprint
                  ttt   = tout 
                  tout  = tstar
                  irtrn = -3
                  bstop = .true.
                  print *,'Line contact at ',tstar
                  cycle
               endif
!
         else if (thh(kend) > hpi - theta_stop ) then
               j1 = kstart
               j2 = j1 + 1
               if (j2 > ksize) j2 = 1
               j3 = kend
!
                p(0) = thh(j2) - (hpi - theta_stop)
               p(1) = (thh(j3) - thh(j1))/(2.0_8*tprint)
               p(2) = (thh(j3) - 2.0_8*thh(j2) + thh(j1))/(2.0_8*tprint**2) 
               ttt  = zeroin( zero, tprint, ztime, abstol)
!
!
               if (ttt >= zero .and. ttt <= tprint) then
                  tstar = tout + ttt - tprint
                  ttt   = tout 
                  tout  = tstar
                  irtrn = -3
                  print *,'Stop at ',tstar
                  bstop = .true.
                  cycle
               endif
         else if (thh(kend) < -hpi + theta_stop ) then
               j1 = kstart
               j2 = j1 + 1
               if (j2 > ksize) j2 = 1
               j3 = kend
!
                p(0) = thh(j2) + (hpi - theta_stop)
               p(1) = (thh(j3) - thh(j1))/(2.0_8*tprint)
               p(2) = (thh(j3) - 2.0_8*thh(j2) + thh(j1))/(2.0_8*tprint**2) 
               ttt  = zeroin( zero, tprint, ztime, abstol)
!
!
               if (ttt >= zero .and. ttt <= tprint) then
                  tstar = tout + ttt - tprint
                  ttt   = tout 
                  tout  = tstar
                  irtrn = -3
                  print *,'Stop at ',tstar
                  bstop = .true.
                  cycle
               endif
         endif
!
         if (mode == rolling) then
            if (fff(kend) > zero) then
!
!              Transition rolling -> sliding
!
!              Calculate transition time
!
               j1 = kstart
               j2 = j1 + 1
               if (j2 > ksize) j2 = 1
               j3 = kend
!
               p(0) = fff(j2)
               p(1) = (fff(j3) - fff(j1))/(2.0_8*tprint)
               p(2) = (fff(j3) - 2.0_8*fff(j2) + fff(j1))/(2.0_8*tprint**2) 
               ttt  = zeroin( zero, tprint, ztime, abstol)
!
               if (ttt >= zero .and. ttt <= tprint) then
                  tstar = tout + ttt - tprint
                  ttt   = tout 
                  tout  = tstar
                  irtrn = -1
                  cycle
               endif
            endif
         else if (mode == sliding) then
            if (vp < abstol) then
!
!              Transition sliding -> rolling
!
!
!              Calculate transition time
!
               j1 = kstart
               j2 = j1 + 1
               if (j2 > ksize) j2 = 1
               j3 = kend
!
               p(0) = vvv(j2)
               p(1) = (vvv(j3) - vvv(j1))/(2.0_8*tprint)
               p(2) = (vvv(j3) - 2.0_8*vvv(j2) + vvv(j1))/(2.0_8*tprint**2)
               if (p(2) > zero) then
                  ttt = -p(1)/(2.0_8*p(2))
               else
                  ttt = tprint
               endif
               ttt = max(zero, min(tprint, ttt))
!
               if (p(0) + p(1)*ttt + p(2)*ttt**2 < abstol) then
                  tstar = tout + ttt - tprint
                  irtrn = -2
               endif
            endif
         endif
!
!        Write results
!
         write( iures, '(30F18.7,6x,a)' , iostat = ier) &
         &   tout, &
         &   psi, theta, phi, & 
         &   omega1, omega2, omega3, &  
         &   vcx, vcy, vcz,   &
         &   xxc, yyc, zzc,   & 
         &   xxp, yyp, zzp,   &
         &   vpx, vpy, vpz,   &
         &   omegax, omegay, omegaz, &  
         &   fx/g, fy/g, fz/g,      &
         &   fn/g, ft/g, xmu,     &
         &   vp , alpha, cmode(mode)
!
         if (ier /= 0) then
            write(*,*) ' *** solout: write IO error #',IER
	         stop
	      endif
!
          nout = nout + 1
          if (tend > tstart) then
             percent = int(100.0_8*(tout - tstart)/(tend - tstart))
             percent = max(0, min(100, percent))
             if (percent > last_percent) then
                width = 32
                filled = percent*width/100
                write(*,'(a,a,a,a,i3,a,f8.3,a)',advance='no') &
                &  achar(13), '[', repeat('#', filled), &
                &  repeat('-', width-filled)//'] ', percent, '%  t=', tout, ' s'
                last_percent = percent
             endif
          endif
          if (nr == 1) exit
!
         tout = tout + tprint
         if (irtrn < 0) then
            ttt   = tout 
            tout  = tstar
         endif
!
      enddo
!      tstar = tout
!
      end subroutine solout
