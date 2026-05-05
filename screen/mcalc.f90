      module mcalc
!
!  Purpose---
!     Calculator
!
!  Syntax---
!     call calc( string, number, stat)
!
!  Arguments---
!     string      character(*)   in    input string
!     number      number         out   double, real or integer number
!     stat        integer        out   output status 0=OK
!
!  Modules used---
!     NONE
!
      implicit none
      private
!
!  Public subroutines---
      public :: calc
!
!  Interfaces---
      interface calc
         module procedure calc_d, calc_r, calc_i
      end interface       
!
!  Parameters---
      character(*), parameter :: alpha = &
               & 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
      character(*), parameter :: digit = '0123456789'
!
      integer, parameter :: AL       = 8
      integer, parameter :: MAXSTACK = 32
!
      integer, parameter :: MEOL       = -1
      integer, parameter :: MNULL      = 0
      integer, parameter :: MIDENT     = 1
      integer, parameter :: MNUMBER    = 2
      integer, parameter :: MFUNCTION  = 3
      integer, parameter :: MPLUS      = 4
      integer, parameter :: MMINUS     = 5
      integer, parameter :: MTIMES     = 6
      integer, parameter :: MSLASH     = 7
      integer, parameter :: MPOWER     = 8
      integer, parameter :: MLPAREN    = 9
      integer, parameter :: MRPAREN    = 10
!
      integer, parameter :: MPI        = 20
      integer, parameter :: MSQRT      = 21
      integer, parameter :: MEXP       = 22
      integer, parameter :: MSIN       = 23
      integer, parameter :: MCOS       = 24
      integer, parameter :: MTAN       = 25
      integer, parameter :: MASIN      = 26
      integer, parameter :: MACOS      = 27
      integer, parameter :: MATAN      = 28
      integer, parameter :: MABS       = 29
      integer, parameter :: MLN        = 30
      integer, parameter :: MLOG       = 31
      integer, parameter :: MSINH      = 32
      integer, parameter :: MCOSH      = 33
      integer, parameter :: MTANH      = 35
!
      real(8), parameter :: PI  = 3.1415926535897932384626433832795_8
      real(8), parameter :: RPD = PI/180.0_8
      real(8), parameter :: DPR = 180.0_8/PI
      real(8), parameter :: E   = 2.7182818284590452353602874713527_8
!   
! Variables---
!
      character(255) :: line
      character :: ch         ! Last character read
      integer   :: cc         ! Character count
      integer   :: ll         ! Line length
      integer   :: kk
      integer   :: sym        ! Last symbol read
      integer   :: ierr       ! Error indicator
      real(8)   :: num        ! Last number read
      character(AL) :: id     ! Last identifier read
      character(AL) ::a
      integer   :: fun        ! Last function read

      integer   :: itop       ! Top of stack
      real(8)   :: stack(MAXSTACK)
!
      integer, parameter :: NORW = 14
      character(4), parameter :: cFunc(NORW) = (/ &
           & 'ABS ', 'SQRT', 'EXP ', 'LN  ', 'LOG ', 'SIN ', 'COS ','TAN ', &
           & 'ASIN', 'ACOS', 'ATAN', 'SINH', 'COSH', 'TANH'/)
      integer, parameter :: iFunc(NORW) = (/ &
           & MABS , MSQRT, MEXP, MLN  , MLOG , MSIN , MCOS, MTAN, &
           & MASIN, MACOS,  MATAN, MSINH, MCOSH, MTANH /)
!
      contains
!
!******************************************************************************!
!
      subroutine calc_d( cLine, rVal, istat)
!
!  Purpose---
!     Calculator.
!
!  Modules used---
!     NONE

!  Arguments---
      character(*), intent(in)  :: cLine
      real(8),      intent(out) :: rVal
      integer, optional, intent(out) :: istat
!
!  FORTRAN functions called---
      intrinsic  len_trim
!
!  Local variables---
      integer :: i
!
!  Executable statements---
!
!     Initialize
!
      cc   = 0
      ll   = 0
      ierr = 0
      itop = 0
!
!     Check. Too big or empty ?
!
      ll = len_trim(cLine)
      if (ll > 255 .or. ll == 0) then
         ierr = -1
         goto 999    
      endif
!
!     Local copy of input line
!
      line(1:ll) = cLine(1:ll)
!
!     Convert line to all uppercase
!
      do i = 1, ll
         ch = line(i:i)
         if (ch >= 'a' .and. ch <= 'z')  line(i:i) = char(ichar(ch)-32)
      enddo
      line(ll+1:ll+1) = ' '
!
!     Scan line
!
      ch = ' '
      call getsym
      call expression
!
!     Any errors ?
!
      if (ierr /= 0) goto 999
!
!     Get value
!
      rVal = (pop())
!
!     Exit
!    
999   continue
      if (present(istat)) istat = ierr
!                             
      end subroutine calc_d
!
!==============================================================================!
!
      subroutine calc_r( cLine, rVal, istat)
!
!  Purpose---
!     Calculator.
!
!  Modules used---
!     NONE

!  Arguments---
      character(*), intent(in)  :: cLine
      real(4),      intent(out) :: rVal
      integer, optional, intent(out) :: istat
!
!  Local variables---
      integer :: ist
      real(8) :: dval
!
!  Executable statements---
!
      call calc_d( cline, dval, ist)
      if (ist == 0) rval = real(dval)
      if (present(istat)) istat = ist
!
      end subroutine calc_r
!
!==============================================================================!
!
      subroutine calc_i( cLine, ival, istat)
!
!  Purpose---
!     Calculator.
!
!  Modules used---
!     NONE

!  Arguments---
      character(*), intent(in)  :: cLine
      integer,      intent(out) :: ival
      integer, optional, intent(out) :: istat
!
!  Local variables---
      integer :: ist
      real(8) :: dval
!
!  Executable statements---
!
      call calc_d( cline, dval, ist)
      if (ist == 0) ival = idnint(dval)
      if (present(istat)) istat = ist
!
      end subroutine calc_i
!
!******************************************************************************!
!
      recursive subroutine expression
!
! Local variables---
      integer :: isign , op
      real(8) :: op1, op2
!
! Executable statements---
!
      isign = 1
      if (sym == MPLUS .or. sym == MMINUS) then
         if (sym == MMINUS) isign = -1
         call getsym
      endif
!
      call term
      if (ierr /= 0) return
!
      if (isign == -1) stack(itop) = -stack(itop)
!
      do while (sym == MPLUS .or. sym == MMINUS)
!
         op = sym ! Remember operator
!
         call getsym
         call term
         if (ierr /= 0) return
!
         op2 = pop()
         op1 = pop()
!
         select case (op)
!         
         case (MPLUS)
            call push( op1 + op2)
!         
         case (MMINUS)
            call push( op1 - op2)
!
         end select
!
      enddo
!
      end subroutine expression
!
!------------------------------------------------------------------------------!
!
      recursive subroutine term
!
! Local variables---
      integer :: isign , op
      real(8) :: op1, op2
!
! Executable statements---
!
      call factor1
      if (ierr /= 0) return
!
      do while (sym == MTIMES .or. sym == MSLASH) ! .or. sym == MPOWER)
!
         op = sym ! Remember operator
!
         call getsym
         call factor1
         if (ierr /= 0) return
!
         op2 = pop()
         op1 = pop()
!
         select case (op)
!         
         case (MTIMES)
            call push( op1 * op2)
!         
         case (MSLASH)
            if (op2 == 0.0_8) then
               ierr = -4
               call push(0.0_8)
            else
               call push( op1 / op2)
            endif
!   
         case (MPOWER)
            call push( op1**op2)
!
         end select
!
      enddo
!
      end subroutine term
!
!------------------------------------------------------------------------------!
!
      recursive subroutine factor1
!
! Local variables---
      integer :: isign , op
      real(8) :: op1, op2
!
! Executable statements---
!
      call factor
      if (ierr /= 0) return
!
      do while (sym == MPOWER)
!
         call getsym
         call factor
         if (ierr /= 0) return
!
         op2 = pop()
         op1 = pop()
!
            call push( op1**op2)
!
      enddo
!
      end subroutine
!
!------------------------------------------------------------------------------!

      recursive subroutine factor
!
! Local variables---
      integer :: ifun
      real(8) :: op1, op2
!
! Executable statements---
!
      if (sym == MIDENT) then
         if (id(1:4) == 'PI  ') then
            num = PI
         elseif (id(1:4) == 'RPD ') then
            num = RPD
         elseif (id(1:4) == 'DPR ') then
            num = DPR
         elseif (id(1:4) == 'E   ') then
            num = E
         else
            ierr = -1
         endif
         call push(num)
         call getsym
!
      else if (sym == MNUMBER) then
         call push(num)
         call getsym
!
      else
         ifun = 0
         if (sym == MFUNCTION) then
            ifun = fun
            call getsym
         endif
!
         if (sym == MLPAREN) then
            call getsym
!            
            call expression      ! <==== recursive call
            if (ierr /= 0) return
!
            if (sym == MRPAREN) then
!               
               select case (ifun)
!               
               case (MABS)
                  stack(itop) = abs(stack(itop))
!               
               case (MSQRT)
                  if (stack(itop) >= 0.0_8) then
                     stack(itop) = sqrt(stack(itop))
                  else
                     ierr = -11
                  endif
!               
               case (MEXP)
                  stack(itop) = exp(stack(itop))
!
               case (MLN)
                  if (stack(itop) > 0.0_8) then
                     stack(itop) = log(stack(itop))
                  else
                     ierr = -11
                  endif
!
               case (MLOG)
                  if (stack(itop) > 0.0_8) then
                     stack(itop) = log10(stack(itop))
                  else
                     ierr = -11
                  endif
!
               case (MSIN)
                  stack(itop) = sin(RPD*stack(itop))
!
               case (MCOS)
                  stack(itop) = cos(RPD*stack(itop))
!
               case (MTAN)
                  stack(itop) = tan(RPD*stack(itop))
!
               case (MASIN)
                  if (abs(stack(itop)) <= 1.0) then
                     stack(itop) = asin(stack(itop))/RPD
                  else
                     ierr = -11
                  endif
!
               case (MACOS)
                  if (abs(stack(itop)) <= 1.0) then
                     stack(itop) = acos(stack(itop))/RPD
                  else
                     ierr = -11
                  endif
!
               case (MATAN)
                  stack(itop) = atan(stack(itop))/RPD
!
               case (MSINH)
                  stack(itop) = sinh(stack(itop))
!
               case (MCOSH)
                  stack(itop) = cosh(stack(itop))
!
               case (MTANH)
                  stack(itop) = tanh(stack(itop))
!                                                                                                                        
               end select
!
               call getsym
            else
               ierr = -1
            endif
         else
            ierr = -1
         endif
!                              
      end if
!
      end subroutine factor

!------------------------------------------------------------------------------!
!
      subroutine getsym
!
! Local variables---
!
      integer i, k
!
! Executable statements---
!
      if (cc > ll) then
         sym = MEOL
         return
      endif
!
      do while (ch == ' ')
         call getch
      enddo
!
      if (index(alpha,ch) /= 0) then
         ! identifier or reserved word
         a = ' '
         k = 0
         do
            if (k < AL) then
               k      = k + 1
               a(k:k) = ch
            endif
            call getch
            if (ch /= '_' .and. index(alpha//digit,ch) == 0) exit
         enddo
         !if (k >= kk) then
         !   kk = k
         !else
         !   do
         !      a(kk:kk) = ' '
         !      kk = kk -1
         !      if (kk == k) exit
         !   enddo
         !endif
        ! kk = k
         id = a !(1:kk) = a(1:kk)
        ! kk = len_trim(id)
!
         do i = 1, NORW
            if (id(1:4) == cFunc(i)(1:4)) then
               k = i
               exit
            endif
         enddo
!
         if (i > NORW) then
            sym = MIDENT
         else
            fun = iFunc(k)
            sym = MFUNCTION
         endif
!
      else if (index(digit,ch) /= 0 .or. ch == '.' .or. ch == ',') then
         ! Number
         num = 0.0_8
         sym = MNUMBER
         call getnumber
!     
      else
!         
         select case (ch)        
            case ('+')   ; sym = MPLUS
            case ('-')   ; sym = MMINUS
            case ('*')   ; sym = MTIMES
            case ('/')   ; sym = MSLASH
            case ('(')   ; sym = MLPAREN
            case (')')   ; sym = MRPAREN
            case ('^')   ; sym = MPOWER
            case default ; sym = MNULL        
         end select
         if (sym == MTIMES) then
            call getch
            if (ch == '*') then
               sym = MPOWER
               call getch
            endif
         else
            call getch
         endif
      endif
!
      end subroutine getsym
!
!------------------------------------------------------------------------------!
!
      subroutine getnumber
!
! Local variables---
      integer :: knum, isgn
      real(8) :: scale
      logical :: seen_digit
!
! Executable statements---
!
      num = 0.0_8
      seen_digit = .false.
!
      do while (index(digit,ch) /= 0)
         seen_digit = .true.
         num = 10.0_8*num + dble(ichar(ch) - ichar('0'))
         call getch
      enddo

      if (ch == '.' .or. ch == ',') then
         call getch
         scale = 0.1_8
         do while (index(digit,ch) /= 0)
            seen_digit = .true.
            num = num + scale*dble(ichar(ch) - ichar('0'))
            scale = 0.1_8*scale
            call getch
         enddo
      endif
!
      if (.not. seen_digit) then
         ierr = -6
         return
      endif
!
      if (ch == 'E' .or. ch == 'D') then
         call getch
         isgn = 1
         if (ch == '+' .or. ch == '-') then
            if (ch == '-') isgn = -1
            call getch
         endif
         if (index(digit,ch) /= 0) then
            knum = 0
            do while (index(digit,ch) /= 0)
               knum = 10*knum + (ichar(ch) - ichar('0'))
               call getch
            enddo
            num = num*10.0_8**(knum*isgn)
         else
            ierr = -6
         endif
      endif
!
      end subroutine getnumber
!
!------------------------------------------------------------------------------!
!
      subroutine getch
!
!  Executable statements---
!
      cc = cc + 1
      ch = line(cc:cc)
!
      end subroutine getch
!
!------------------------------------------------------------------------------!
!
      real(8) function pop()
!
! Executable statements---
!
      if (itop < 1) then
         ierr = -2
         return
      endif
!
      pop  = stack(itop)
    !!  print *,'pop  :',itop,pop
      itop = itop - 1
!
end function pop
!
!------------------------------------------------------------------------------!
!
      subroutine push( dVal)
!
!  Arguments---
      real(8), intent(in) :: dVal
!
!  Executable statements---
!
      if (itop >= MAXSTACK) then
         ierr = -3
         return
      endif
!
      itop        = itop + 1
      stack(itop) = dVal
   !!   print *,'push :',itop,dval
!
      end subroutine push
!
!==============================================================================!
!
      end module mcalc

