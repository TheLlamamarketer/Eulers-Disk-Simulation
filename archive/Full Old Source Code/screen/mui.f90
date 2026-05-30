module mui
!
!  Purpose---
!     A simple user interface tools
!
!
!     Data input
!     ==========
!
!     Syntax:
!
!        get_number( prompt, value, [fmt], [minv], [maxv], [stat])
!        get_string( string, [stat])
!        get_choice( options, copt, [stat])
!        get_choice( ilow, ihigh, iopt, [stat])

!  Modules used---
      use mcalc,  only: calc
      use mn2c,   only: n2c
      use mchr,   only: chr_upper, chr_lower
!
   implicit none
   private
!
!  Public subroutines---
      public :: get_choice
      public :: get_number
      public :: get_string
      public :: get_yesno
!
      public :: set_number
      public :: set_string
      public :: skip_lines
      public :: new_page
      public :: set_line
      public :: set_pause
!
!  Interfaces---
      interface get_number
         module procedure get_number_d, get_number_r, get_number_i
      end interface
!
      interface get_choice
         module procedure get_choice_s, get_choice_i, get_choice_n
      end interface
!
      interface set_number
         module procedure set_number_d , set_number_i, set_number_r
      end interface
!
      interface set_string
         module procedure set_string_col , set_string_center
      end interface
!
!  Local parameters---
!
      integer, parameter :: ERR_SYNTAX    = -1
      integer, parameter :: ERR_UNDERFLOW = -2
      integer, parameter :: ERR_OVERFLOW  = -3
      integer, parameter :: ERR_YESNO     = -4
      integer, parameter :: ERR_OPT       = -5
!
      integer, parameter :: SCR_WIDTH     = 79
      integer, parameter :: MAX_LINES     = 25
!
!  Local variables---
      integer       :: iout = 0
      integer       :: ierr
      integer       :: nlin = 0
      character(80) :: cbuff
!
contains
!
!==============================================================================!
!
subroutine set_pause()
   call writeln()
   call readln('Press <Enter> to continue')
end subroutine
!
!==============================================================================!
!
subroutine  get_number_d( prompt, dval, fmt, minv, maxv, stat)
!
!  Purpose---
!     Get number
!
!  Arguments---
      character(*), intent(in)      :: prompt
      real(8),      intent(inout)   :: dval
!
!  Optional arguments---
      character(*), optional, intent(in)  :: fmt
      real(8),      optional, intent(in)  :: minv
      real(8),      optional, intent(in)  :: maxv
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl, len_trim
!
!  Local parameters---
!     NONE
!
!  Local variables---
      character(7)   :: cfmt
      character(32)  :: cval, cmin, cmax
!
!  Executable statements---
!
      cval = ' '
      cmin = ' '
      cmax = ' '
!     
!     Pack arguments in strings for compact and nicer prompt
!
      if (present(fmt)) then
         if (len_trim(fmt) > 5) then
            ierr = -1
            goto 999
         endif
         cfmt ='('//fmt(1:len_trim(fmt))//')'
      else
         cfmt ='(g13.4)'                
      endif
!
      if (present(minv)) then
         call n2c( minv, cmin, cfmt, ierr)
         if (ierr /= 0) goto 999
         cmin = adjustl(cmin)
         if (dval < minv) dval = minv
      endif
!
      if (present(maxv)) then
         call n2c( maxv, cmax, cfmt, ierr)
         if (ierr /= 0) goto 999
         cmax = adjustl(cmax)
         if (dval > maxv) dval = maxv
      endif
!
      call n2c( dval, cval, cfmt, ierr)
      if (ierr /= 0) goto 999
      cval = adjustl(cval)
!
!     Get input, check for I/O error
!
      do
!
         if (present(minv) .or. present(maxv)) then
            call readln( prompt(1:len_trim(prompt))//' ['//  &
                     &  cmin(1:len_trim(cmin))//':'//        &
                     &  cmax(1:len_trim(cmax))//'] (<CR>='// &
                     &  cval(1:len_trim(cval))//')')
         else
            call readln( prompt(1:len_trim(prompt)) // &
                     &  ' (<CR>='//cval(1:len_trim(cval))//')')
         endif
         if (ierr /= 0) goto 999
!
!        Empty line ?
         if (len_trim(cbuff) == 0) exit      
!
!        Interpret input, check for syntax error and out of range error
!
         call calc( cbuff, dval, ierr)
         if (ierr /= 0) then
            call errmsg( ERR_SYNTAX)
         else
            if (present(minv)) then
               if (dval < minv) then
                  call errmsg( ERR_UNDERFLOW)
                  ierr = -1
               endif
            endif
            if (present(maxv)) then
               if (dval > maxv) then
                  call errmsg( ERR_OVERFLOW)
                  ierr = -1
               endif
            endif
         endif
         if (ierr == 0) exit
!
      enddo
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine get_number_d
!
!==============================================================================!
!
subroutine  get_number_i( prompt, ival, fmt, minv, maxv, stat)
!
!  Purpose---
!     Get number
!
!  Arguments---
      character(*), intent(in)      :: prompt
      integer,      intent(inout)   :: ival
!
!  Optional arguments---
      character(*), optional, intent(in)  :: fmt
      integer,      optional, intent(in)  :: minv
      integer,      optional, intent(in)  :: maxv
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl, len_trim
!
!  Local parameters---
!     NONE
!
!  Local variables---
      character(7)   :: cfmt
      character(12)  :: cval, cmin, cmax
!
!  Executable statements---
!
      cval = ' '
      cmin = ' '
      cmax = ' '
!     
!     Pack arguments in strings for compact and nicer prompt
!
      if (present(fmt)) then
         if (len_trim(fmt) > 5) then
            ierr = -1
            goto 999
         endif
         cfmt ='('//fmt(1:len_trim(fmt))//')'
      else
         cfmt ='(i13)'                
      endif
!
      if (present(minv)) then
         call n2c( minv, cmin, cfmt, ierr)
         if (ierr /= 0) goto 999
         cmin = adjustl(cmin)
         if (ival < minv) ival = minv
      endif
!
      if (present(maxv)) then
         call n2c( maxv, cmax, cfmt, ierr)
         if (ierr /= 0) goto 999
         cmax = adjustl(cmax)
         if (ival > maxv) ival = maxv
      endif
!
      call n2c( ival, cval, cfmt, ierr)
      if (ierr /= 0) goto 999
      cval = adjustl(cval)
!
!     Get input, check for I/O error
!
      do
!
         if (present(minv) .or. present(maxv)) then
            call readln( prompt(1:len_trim(prompt))//' ['//  &
                     &  cmin(1:len_trim(cmin))//':'//        &
                     &  cmax(1:len_trim(cmax))//'] (<CR>='// &
                     &  cval(1:len_trim(cval))//')')
         else
            call readln( prompt(1:len_trim(prompt)) // &
                     &  ' (<CR>='//cval(1:len_trim(cval))//')')
         endif
         if (ierr /= 0) goto 999
!
!        Empty line ?
         if (len_trim(cbuff) == 0) exit      
!
!        Interpret input, check for syntax error and out of range error
!
         call calc( cbuff, ival, ierr)
         if (ierr /= 0) then
            call errmsg( ERR_SYNTAX)
         else
            if (present(minv)) then
               if (ival < minv) then
                  call errmsg( ERR_UNDERFLOW)
                  ierr = -1
               endif
            endif
            if (present(maxv)) then
               if (ival > maxv) then
                  call errmsg( ERR_OVERFLOW)
                  ierr = -1
               endif
            endif
         endif
         if (ierr == 0) exit
!
      enddo
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine get_number_i
!
!==============================================================================!
!
subroutine  get_number_r( prompt, rval, fmt, minv, maxv, stat)
!
!  Purpose---
!     Get number
!
!  Arguments---
      character(*), intent(in)      :: prompt
      real(4),      intent(inout)   :: rval
!
!  Optional arguments---
      character(*), optional, intent(in)  :: fmt
      real(4),      optional, intent(in)  :: minv
      real(4),      optional, intent(in)  :: maxv
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl, len_trim
!
!  Local parameters---
!     NONE
!
!  Local variables---
      character(7)   :: cfmt
      character(12)  :: cval, cmin, cmax
!
!  Executable statements---
!
      cval = ' '
      cmin = ' '
      cmax = ' '
!     
!     Pack arguments in strings for compact and nicer prompt
!
      if (present(fmt)) then
         if (len_trim(fmt) > 5) then
            ierr = -1
            goto 999
         endif
         cfmt ='('//fmt(1:len_trim(fmt))//')'
      else
         cfmt ='(g13.4)'                
      endif
!
      if (present(minv)) then
         call n2c( minv, cmin, cfmt, ierr)
         if (ierr /= 0) goto 999
         cmin = adjustl(cmin)
         if (rval < minv) rval = minv
      endif
!
      if (present(maxv)) then
         call n2c( maxv, cmax, cfmt, ierr)
         if (ierr /= 0) goto 999
         cmax = adjustl(cmax)
         if (rval > maxv) rval = maxv
      endif
!
      call n2c( rval, cval, cfmt, ierr)
      if (ierr /= 0) goto 999
      cval = adjustl(cval)
!
!     Get input, check for I/O error
!
      do
!
         if (present(minv) .or. present(maxv)) then
            call readln( prompt(1:len_trim(prompt))//' ['//  &
                     &  cmin(1:len_trim(cmin))//':'//        &
                     &  cmax(1:len_trim(cmax))//'] (<CR>='// &
                     &  cval(1:len_trim(cval))//')')
         else
            call readln( prompt(1:len_trim(prompt)) // &
                     &  ' (<CR>='//cval(1:len_trim(cval))//')')
         endif
         if (ierr /= 0) goto 999
!
!        Empty line ?
         if (len_trim(cbuff) == 0) exit      
!
!        Interpret input, check for syntax error and out of range error
!
         call calc( cbuff, rval, ierr)
         if (ierr /= 0) then
            call errmsg( ERR_SYNTAX)
         else
            if (present(minv)) then
               if (rval < minv) then
                  call errmsg( ERR_UNDERFLOW)
                  ierr = -1
               endif
            endif
            if (present(maxv)) then
               if (rval > maxv) then
                  call errmsg( ERR_OVERFLOW)
                  ierr = -1
               endif
            endif
         endif
         if (ierr == 0) exit
!
      enddo
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine get_number_r
!
!==============================================================================!
!
subroutine get_choice_s( prompt, choice, copt, stat)
!
!  Arguments---
      character(*), intent(in)    :: prompt
      character(*), intent(in)    :: choice
      character(1), intent(inout) :: copt
!
!  Optional arguments---
      integer, optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl
!
!  Local variables---
      integer :: ipos
!
!  Executable statements---
!
      do
         call readln(prompt//' (<CR>='//copt(1:len_trim(copt))//')')
         if (ierr /= 0)  goto 999
!
!        Default value
!
         if (len_trim(cbuff) == 0) exit
!
         cbuff = adjustl(cbuff)
         ipos  = index(choice,cbuff(1:1))
         if (ipos /= 0) then
            copt = cbuff(1:1)
         else
            call errmsg(ERR_OPT)
            ierr = -1
         endif
         if (ierr == 0) exit
      enddo
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine get_choice_s    
!
!==============================================================================!
!
subroutine get_choice_i( prompt, choice, iopt, stat)
!
!  Arguments---
      character(*), intent(in)  :: prompt
      character(*), intent(in)  :: choice
      integer,      intent(out) :: iopt
!
!  Optional arguments---
      integer, optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl
!
!  Local variables---
      integer :: ipos
!
!  Executable statements---
!
      call readln( prompt)
      if (ierr == 0)  then
         cbuff = adjustl(cbuff)
         ipos = index(choice,cbuff(1:1))
         if (ipos /= 0) then
            iopt = ipos
         else
            ierr = -1
         endif
      endif
!
      if (present(stat)) stat = ierr
!
end subroutine get_choice_i
!
!==============================================================================!
!
subroutine get_choice_n( prompt, ilow, ihigh, iopt, stat)
!
!  Arguments---
      character(*), intent(in)  :: prompt
      integer, intent(in)  :: ilow, ihigh
      integer, intent(out) :: iopt
!
!  Optional arguments---
      integer, optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   sngl
!
!  Local variables---
      real(4) :: ropt
!
!  Executable statements---
!
      if (ilow >= ihigh) then
         ierr = -1
         goto 999
      endif
!
      call readln( prompt)
      if (ierr == 0)  then
         call calc( cbuff, ropt, ierr)
         if (ierr == 0) then
            iopt = nint( ropt)
            if (iopt < ilow .or. iopt > ihigh) ierr = -1
         endif      
      endif
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine get_choice_n
!
!==============================================================================!
!
subroutine get_string( prompt, string, case, length, stat)
!
!  Purpose---
!     Read a line from console
!
!  Arguments---
      character(*), intent(in)  :: prompt
      character(*), intent(out) :: string
!
!  Optional arguments---
      integer,      optional, intent(out) :: length
      character(*), optional, intent(in)  :: case
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl, len, len_trim, min
!
!  Local parameters---
     ! integer, parameter :: aoffset = 32
!
!  Local variables---
      integer ::  ll
!
!  Executable statements---
!
      string = adjustl(string) 
      ll = min( len_trim(string), len(cbuff))
!
      call readln( prompt//' (<CR>= '//string(1:ll)//')')
      if (ierr /= 0) goto 999
!
!     Not empty line ?
      if (len_trim(cbuff) /= 0) then
         ll = min( len(string), len_trim(cbuff))
         string(1:ll) = cbuff(1:ll)
      endif
!
!     Get string length if requested
!
      if (present(length)) length = len_trim(string)
!        
!     Convert string to upper/lower case if requested
!     
      if (present(case)) then
!
         if (case == 'u' .or. case == 'U') then
            call chr_upper(string)
           ! do is = 1, len_trim(string)
           !    ia = iachar(string(is:is))
           !    if (ia >= iachar('a').and.ia <= iachar('z')) &
           !        string(is:is) = achar(ia-aoffset)
           ! enddo
         endif
!
         if (case == 'l' .or. case == 'L') then
           call chr_lower(string) 
           ! do is = 1, len_trim(string)
           !    ia = iachar(string(is:is))
           !    if (ia >= iachar('A').and.ia <= iachar('Z')) &
           !        string(is:is) = achar(ia+aoffset)
           ! enddo
         endif
!
      endif
!
!     Return status if requested
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine get_string
!
!==============================================================================!
!
subroutine get_yesno( prompt, bval, default, stat)
!
!  Arguments---
      character(*), intent(in)  :: prompt
      logical     , intent(out) :: bval
!
!  Optional arguments---
      logical, optional, intent(in) :: default
      integer,      optional, intent(out) :: stat
!
!  Local variables---
      character(3) :: string
!
!  Executable statements----
!      
!
!     If present, set default 
!
      if (present(default)) bval = default 
!      
!     Default answer yes/no
!     
      if (bval) then
         string = 'yes'
      else
         string = 'no'
      endif
!
      do
!      
!        Write prompt string to terminal
!
         call readln( prompt//' (<CR>= '//string(1:len_trim(string))//')')
         if (ierr /= 0) goto 999
!
!        Not empty line ?
         if (len_trim(cbuff) == 0) return     
!
!        Translate answer in .true./.false., if invalid prompt again
!    
         select case (adjustl(cbuff(1:1)))
         case ('y','Y','t','T')
            bval = .true.
         case ('n','N','f','F')
            bval = .false.
         case default
            call errmsg( ERR_YESNO)
            ierr = - 1
         end select
!      
         if (ierr == 0) exit
!
      enddo
!
!     Return status if requested
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine get_yesno
!
!==============================================================================!
!
subroutine  set_number_d( icol, prompt, dval, fmt, adjust, stat)
!
!  Purpose---
!     Set number
!
!  Arguments---
      integer,      intent(in) :: icol
      character(*), intent(in) :: prompt
      real(8),      intent(in) :: dval
!
!  Optional arguments---
      character(*), optional, intent(in)  :: fmt
      character(*), optional, intent(in)  :: adjust   ! L C R
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl, len_trim
!
!  Local parameters---
!     NONE
!
!  Local variables---
      character(7)   :: cfmt
      character(16)  :: cval
      integer        :: ll
!
!  Executable statements---
!
      cval = ' '
!     
!     Pack arguments in strings for compact and nicer output
!
      if (present(fmt)) then
         if (len_trim(fmt) > 5) then
            ierr = -1
            goto 999
         endif
         cfmt ='('//fmt(1:len_trim(fmt))//')'
      else
         cfmt ='(g13.4)'                
      endif
!
      call n2c( dval, cval, cfmt, ierr)
      if (ierr /= 0) goto 999
!
      if (present(adjust)) then
         select case (adjust(1:1))
         case ('l','L')
            cval = adjustl(cval)
         case ('c','C')
!!!!!------>            
         case ('r','R')
            cval = adjustr(cval)
         end select
      endif
!
      ll = min(len(prompt),SCR_WIDTH - len_trim(cval))
      cbuff = prompt(1:ll)//cval(1:len_trim(cval))
      call writeln( cbuff , icol-1)
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine set_number_d
!
!==============================================================================!
!
subroutine  set_number_i( icol, prompt, ival, fmt, adjust, stat)
!
!  Purpose---
!     Set number
!
!  Arguments---
      integer,      intent(in) :: icol
      character(*), intent(in) :: prompt
      integer,      intent(in) :: ival
!
!  Optional arguments---
      character(*), optional, intent(in)  :: fmt
      character(*), optional, intent(in)  :: adjust   ! L C R
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl, len_trim
!
!  Local parameters---
!     NONE
!
!  Local variables---
      character(7)   :: cfmt
      character(16)  :: cval
      integer        :: ll
!
!  Executable statements---
!
      cval = ' '
!     
!     Pack arguments in strings for compact and nicer output
!
      if (present(fmt)) then
         if (len_trim(fmt) > 5) then
            ierr = -1
            goto 999
         endif
         cfmt ='('//fmt(1:len_trim(fmt))//')'
      else
         cfmt ='(i13)'                
      endif
!
      call n2c( ival, cval, cfmt, ierr)
      if (ierr /= 0) goto 999
!
      if (present(adjust)) then
         select case (adjust(1:1))
         case ('l','L')
            cval = adjustl(cval)
         case ('c','C')
!!!!!------>            
         case ('r','R')
            cval = adjustr(cval)
         end select
      endif
!
      ll = min(len(prompt),SCR_WIDTH - len_trim(cval))
      cbuff = prompt(1:ll)//cval(1:len_trim(cval))
      call writeln( cbuff , icol-1)
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine set_number_i
!
!==============================================================================!
!
subroutine  set_number_r( icol, prompt, rval, fmt, adjust, stat)
!
!  Purpose---
!     Set number
!
!  Arguments---
      integer,      intent(in) :: icol
      character(*), intent(in) :: prompt
      real(4),      intent(in) :: rval
!
!  Optional arguments---
      character(*), optional, intent(in)  :: fmt
      character(*), optional, intent(in)  :: adjust   ! L C R
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl, len_trim
!
!  Local parameters---
!     NONE
!
!  Local variables---
      character(7)   :: cfmt
      character(16)  :: cval
      integer        :: ll
!
!  Executable statements---
!
      cval = ' '
!     
!     Pack arguments in strings for compact and nicer output
!
      if (present(fmt)) then
         if (len_trim(fmt) > 5) then
            ierr = -1
            goto 999
         endif
         cfmt ='('//fmt(1:len_trim(fmt))//')'
      else
         cfmt ='(g13.4)'                
      endif
!
      call n2c( rval, cval, cfmt, ierr)
      if (ierr /= 0) goto 999
!
      if (present(adjust)) then
         select case (adjust(1:1))
         case ('l','L')
            cval = adjustl(cval)
         case ('c','C')
!!!!!------>            
         case ('r','R')
            cval = adjustr(cval)
         end select
      endif
!
      ll = min(len(prompt),SCR_WIDTH - len_trim(cval))
      cbuff = prompt(1:ll)//cval(1:len_trim(cval))
      call writeln( cbuff, icol-1)
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine set_number_r
!
!==============================================================================!
!
subroutine set_string_col( icol, text, stat)
!
!  Purpose---
!     Read a line from console
!
!  Arguments---
      integer,      intent(in) :: icol
      character(*), intent(in) :: text
!
!  Optional arguments---
      integer,      optional, intent(out) :: stat
!
!  FORTRAN---
      intrinsic  len_trim
!
!  Local variables--- 
      integer :: ilen, ipos
!
!  Executable statements---
!
      ilen = len_trim( text)
      if (ilen == 0) then
         call writeln()
         return
      endif
!
      if (icol > 0 .and. icol < SCR_WIDTH) then
         if (ilen + icol > SCR_WIDTH) then
            !return
            ilen = SCR_WIDTH - icol
         endif
!
         if (ilen <= 0) then
            call writeln()
            goto 999
         endif
!
         ipos = icol 
         else
            call writeln()
            goto 999
      endif
!
      cbuff(:) = ' '
      cbuff(ipos:ipos+ilen) = text(1:ilen)
!
      call writeln(cbuff)
!
!     Return status if requested
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine set_string_col
!
!==============================================================================!
!
subroutine set_string_center( string, stat)
!
!  Purpose---
!     Read a line from console
!
!  Arguments---
      character(*), intent(in) :: string
!
!  Optional arguments---
      integer,      optional, intent(out) :: stat
!
!  FORTRAN functions called---
      intrinsic   adjustl, len, len_trim
!
!  Local variables---
      integer :: is, ll
!
!  Executable statements---
!
      ll = len( string)
      if (ll == 0) then
         call writeln()
         return
      endif
!
      if (ll > SCR_WIDTH) then
      !return
         ll = SCR_WIDTH
      endif
!
      is = (SCR_WIDTH - ll)/2 + 1
      cbuff(:) = ' '
      cbuff(is:is+ll) = string(1:ll)
!
      call writeln(cbuff)
!
!     Return status if requested
!
999   continue
      if (present(stat)) stat = ierr
!
end subroutine set_string_center
!
!==============================================================================!
!
subroutine skip_lines( nl)
!
!  Arguments---
      integer, intent(in) :: nl
!
!  FORTRAN functions called---
      intrinsic   min
!
!  Local variables---
      integer :: n
!
!  Executable statements---
!
      do n = 1, min(nl,MAX_LINES)
         call writeln()
      enddo
!
end subroutine skip_lines
!
!==============================================================================!
!
subroutine new_page
!
!  Modules used---
!      use mscr
      use mio
!
!  Local variables---
      logical :: binit = .true.
!
!  Executable statements---
!
!      if ( binit) then
!         call new_unit( iout)
!         call scr_open(iout)
!         binit = .false.
!         return
!      endif
!
!      call scr_clear()   
!
end subroutine new_page
!
!==============================================================================!
!
subroutine errmsg( ierr)
!
!  Purpose---
!     Error message
!
!  Arguments---
      integer, intent(in) :: ierr   ! Error number
!
!  Local variables---
      character(60) :: cmsg
!
!  Exacutable statements--
!
      select case (ierr)
      case (ERR_SYNTAX)
         cmsg = 'Syntax error. Try again.'
      case (ERR_UNDERFLOW)
         cmsg = 'Value underflow. Try again.'
      case (ERR_OVERFLOW)
         cmsg = 'Value overflow. Try again.'
      case (ERR_YESNO)
         cmsg = 'Invalid answer. Answer y(es)/t(rue) or n(o)/f(alse).'
      case (ERR_OPT)
         cmsg = 'Invalid option. Try again.'
      case default
         cmsg = 'Unknown error.'
      end select
!
      call writeln(' *** Error: '//cmsg(1:len_trim(cmsg)))
!
end subroutine errmsg
!
!==============================================================================!
!
subroutine readln( prompt)
!
!  Purpose---
!     Read a line from console
!
!  Arguments---
      character(*), intent(in) :: prompt
!
!  Executable statements---
!
!      if (present(prompt)) then
         write( *, '(a)', iostat = ierr, advance = 'no') prompt//': '
         if (ierr /= 0) then
            pause
            return
         endif
!      endif
!
      read( *,'(a)',iostat = ierr) cbuff
!
!      nlin = nlin + 1
!      if (nlin > MAX_LINES) nlin = 1
!
end subroutine readln
!
!==============================================================================!
!
subroutine writeln( text, icol)
!
!  Purpose---
!     Write text to console
!
!  Optional arguments---
      character(*), optional, intent(in) :: text
      integer,      optional, intent(in) :: icol
!
!  FORTRAN functions called---
      intrinsic   len, max, min
!
!  Local parameters---
      character(20) :: cblnk = ' '
!
!  Local variables---
      integer :: ll
!
!  Executable statements---
!
      if (present(text)) then
         if (present(icol)) then           
            if (icol <= 0) then
               ll = (SCR_WIDTH - len(text))/2
            else
               ll = max(0,min( icol, len(cblnk)))
            endif
            write( iout, '(a)', iostat = ierr) cblnk(1:ll)//text(1:len_trim(text))
         else
            write( iout, '(a)', iostat = ierr) text(1:len_trim(text))
         endif
      else  
         write( iout, *)
      endif
      nlin = nlin + 1
      if (nlin > MAX_LINES) nlin = 1
!
end subroutine writeln
!
!==============================================================================!
!
subroutine set_line(NCH,ch)
!
!  Arguments----
      character(1), optional, intent(in) :: ch
      integer, optional, intent(in) :: nch
!  Fortran functions called----
      intrinsic :: repeat
!
   character(1) :: ch1
   integer :: n
!
!  Executable statements---
!
      ch1 = '-'
      n = SCR_WIDTH
      if (present(nch)) n= nch

      if (present(ch)) ch1 = ch
      call writeln(repeat(ch1,n))
!
!
end subroutine set_line
!
!==============================================================================!
!
end module mui