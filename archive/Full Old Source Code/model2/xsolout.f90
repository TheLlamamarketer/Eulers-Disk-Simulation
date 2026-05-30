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
            integer, intent(in) :: i         ! i-th component of solution at t
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
      &  'FX    ', 'FY    ', 'FZ    ', &
      &  'FN    ', 'FT    ', 'XMU   ', &
      &  'VS    ', 'ALPHA ', 'ROLL  '/)
!
!  Local scalars---
      integer, save :: kstart = 1, kend = 0, ksize=3
      integer :: i, ier, k, j1, j2, j3
      real(8) :: xmu, ft, fn, alpha, a0, a1, a2, dd
      logical :: binit = .false.
!
!  Local array---
      real(8) :: xnow(12)
      real(8), save :: vvv(3), fff(3), ttt(3) ! queue
!
! Executable statements---
!
      irtrn = 0
!
      if (.not. binit) then
	      write( iures,'(3X,31(A,6X))') (CHEAD(i),i=1,31)
         nout=0
         binit = .true.
      endif
!         
      k = 0
      do while (t >= tout) 
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
        ! if (irtrn < 0) then
        !    if (mode == rolling) then
        !       mode = sliding
        !    else
        !       mode = rolling
        !    endif
        !    return
        ! endif
!
         fn = fz
         if (fn <= 0) then
            write(*,*) ' *** solout: fn <= 0 at ',tout
            irtrn = -1
            exit
         endif
         ft    = sqrt(fx**2 + fy**2)
         xmu   = ft/fn
         alpha = atan2( fy, fx)
!
!        Add results to queue
!
         kend = kend + 1
         if ( kend   > ksize)  kend   = 1
         if ( kend  == kstart) kstart = kend + 1
         if ( kstart > ksize)  kstart = 1
!  
         ttt(kend) = tout
         vvv(kend) = vp
         fff(kend) = ft - xmus*fn
!
!        Queue is empty at the begining...so fill it
!
         if (nr == 1) then
            do i = kstart, ksize
               vvv(i) = vvv(kend)
               fff(i) = fff(kend)
               ttt(i) = ttt(kend) - (ksize - i + 1)*tprint
            enddo
         endif
!
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
               a0 = fff(j2)
               a1 = (fff(j3) - fff(j1))/(2.0_8*tprint)
               a2 = (fff(j3) - 2.0_8*fff(j2) + fff(j1))/(2.0_8*tprint**2)  
               if (a2 == zero) then
                  if (a1 /= zero) then
                     tstar = - a0/a1
                  else
                     write(*,*) '*** solout a1=a2=0 ***'
                     tstar = zero
                  endif
               else 
                  dd = (a1**2 - 4.0_8*a0*a2)
                  if (dd == zero) then
                     tstar = -a1/(2.0_8*a2)
                  elseif (dd >= zero) then              
                     dd = sqrt(dd)
                     tstar =  (-a1 + dd)/(2.0_8*a2)
                     if (tstar > tprint .or. tstar < -tprint) then
                        tstar = (-a1 - dd)/(2.0_8*a2)
                     endif
                  else
                     write(*,*) '*** solout dd < 0 ***'
                     tstar = zero
                  endif
               endif
               if (tstar >= zero .and. tstar <= tprint) then
                  tstar = told + tstar
                  tout = tout + tprint
               else if (tstar < zero) then
                  tstar = told + tstar
               endif
               write (*,*) 'tstar = ',tstar
               do i = 1, nd
                  if (prec == LOW) then
                     xnow(i) = CONTD5( i, tstar, con, icomp, nd)
                  else if (prec == HIGH) then
                     xnow(i) = CONTD8( i, tstar, con, icomp, nd)
                  else
                  endif
               enddo
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
               call disk0
!
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
               !
               mode  = sliding
               irtrn = -1
               exit
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
               a0 = vvv(j2)
               a1 = (vvv(j3) - vvv(j1))/(2.0_8*tprint)
               a2 = (vvv(j3) - 2.0_8*vvv(j2) + vvv(j1))/(2.0_8*tprint**2)  
               if (a2 == zero) then
                  if (a1 /= zero) then
                     tstar = - a0/a1
                  else
                     write(*,*) '*** solout a1=a2=0 ***'
                     tstar = zero
                  endif
               else 
                  dd = (a1**2 - 4.0_8*a0*a2)
                  if (dd == zero) then
                     tstar = -a1/(2.0_8*a2)
                  elseif (dd >= zero) then              
                     dd = sqrt(dd)
                     tstar =  max((-a1 + dd)/(2.0_8*a2),(-a1 - dd)/(2.0_8*a2))
                  else
                     write(*,*) '*** solout dd < 0 ***'
                     tstar = zero
                  endif
               endif
               if (tstar >= tprint) then
                  tstar = told + tstar
               write (*,*) 'tstar = ',tstar

                  if (told < tstar)   tout = tout + tprint
                 ! enddo
               else if (tstar < tprint) then
                  tstar = told + tstar
               endif
               do i = 1, nd
                  if (prec == LOW) then
                     xnow(i) = CONTD5( i, tstar, con, icomp, nd)
                  else if (prec == HIGH) then
                     xnow(i) = CONTD8( i, tstar, con, icomp, nd)
                  else
                  endif
               enddo
!         
               psi    = xnow(1)
               theta  = xnow(2)
               phi    = xnow(3)
               omega1 = xnow(4)
               omega2 = xnow(5)
               omega3 = xnow(6)
               xxc    = xnow(7)
               yyc    = xnow(8)
               vcx   = xnow(9)
               vcy   = xnow(10)
!
               call disk0
!
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
               !
               mode  = rolling
               irtrn = -1
               exit
            endif
         endif
!
!        Write results
!
         write( iures, '(30F12.6,I4)' , iostat = ier) &
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
         &   vp , alpha, mode
!
         if (ier /= 0) then
            write(*,*) ' *** solout: write IO error #',IER
	         stop
	      endif
!
         nout = nout + 1
         tout = tout + tprint
         if (nr == 1) exit
!
         cycle
         if (irtrn /= 0) then
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
            exit
         endif
      enddo
      tstar = tout
!
      end subroutine solout