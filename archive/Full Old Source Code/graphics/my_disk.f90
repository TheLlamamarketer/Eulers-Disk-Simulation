      module my_disk
!
!  Modules used---
      use dflib, only: beepqq
      use opengl_gl
      use opengl_glu
      use opengl_glut
      use my_view_modifier
      use my_primitives
      use disk_data, only: cgraf
!
      implicit none
      private
      save
!
!  Public routines---
      public :: init
!
      public :: display, idle, input, keyboard
      public :: filltorus, fillground, filldisk
!
!  Private parameters---
      real(8), parameter :: ZERO = 0.0_8
      real(8), parameter :: ONE  = 1.0_8
      real(8), parameter :: PI   = 3.1415926535897932384626433832795_8
      real(8), parameter :: DPR  = 57.295779513082320876798154814105_8
!
!  Private variables---
!
      real(4) :: r , h, rho , rg != 0.037550 ! disk radiue
!
      integer :: ndat = 0        ! number of data
      integer :: ntim = 0        ! current data index
      integer :: tick = 0
      real    :: time = 0.0      ! current relative CPU time
      real    :: tstart          ! CPU start time
      real    :: dt   = 1.0E-3   ! time incriment
      integer :: nstp=5
!
      logical :: ground = .false.   ! draw ground ?
      logical :: gbstop = .false.   ! stop animation ?
      logical :: gfast  = .false.
      logical :: gbtime  = .true.
      logical :: gbauto = .false.
      logical :: gbvoice = .false.

! Private arrays---
      real(4), allocatable :: t(:)                 ! Time
      real(4), allocatable :: PSI(:), THETA(:), PHI(:) ! Euler's angles 3-1-2
      real(4), allocatable :: xc(:), yc(:), zc(:)  ! center point coordinates
      real(4), allocatable :: xp(:), yp(:)         ! contact point coordinates
!
!     ////////////////////////////
      real(glfloat), save :: materialColor(8,4) = reshape( &
      (/ 0.8, 0.8, 0.0, 0.0, 0.0, 0.8, 0.8, 0.0, &
     0.8, 0.0, 0.8, 0.0, 0.8, 0.0, 0.8, 0.0, &
     0.8, 0.0, 0.0, 0.8, 0.8, 0.8, 0.0, 0.0, &
     1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.6 /), &
     (/8,4/))
    real(4), save :: no_mat(3) = (/0.0, 0.0, 0.0/)
!     /////////////////////////////
!
      contains
!
!     ************************************************************************!
!
      subroutine display
! 
!  Purpose--
!     This gets called when the display needs to be redrawn
!
!  Arguments---
!     NONE
!
      CHARACTER(8):: CTIME
      logical bret

! Executable statements---
!
      if (gbauto) then
         call auto_pan( xc(ntim), yc(ntim), zc(ntim))
      else
         call reset_view
      endif
!
      call glClear(ior(GL_COLOR_BUFFER_BIT,GL_DEPTH_BUFFER_BIT))
!
      if (gbtime) then
         if (gbstop) then
         write(ctime,'(f6.3)') t(ntim)

         else
         write(ctime,'(f6.2)') t(ntim)
         endif
         call text(R,R,ctime)
      endif
!    if (.not. bmove) then
!     call glCallList(1)
!      call glutSwapBuffers
!      return
!   endif
!
!################
!
!     Draw ground
!
      call glPushMatrix()
      IF (GROUND) then
         call glPushMatrix()
         call FillGround( rg)
         call glPopMatrix()
      endif
      call glMaterialfv( GL_FRONT, GL_AMBIENT,  no_mat)
      call glMaterialfv( GL_FRONT, GL_DIFFUSE,  no_mat)
      call glMaterialfv( GL_FRONT, GL_SPECULAR,  no_mat)
      call glMaterialf ( GL_FRONT, GL_SHININESS, 100.0_glfloat)
      call glColor3f( 0.0, 0.0, 0.0)
      call gAxes(2*sngl(r))
      call gPolyline( ntim, xp, yp)
      call glPopMatrix()
!
!     Draw disk
!
      call glPushMatrix()
      call glTranslatef(xc(ntim), yc(ntim), zc(ntim))
!
      call glRotatef( PSI(ntim), 0.0, 0.0, 1.0)    ! z
      call glRotatef( THETA(ntim), 1.0, 0.0, 0.0)    ! x
      call glRotatef( PHI(ntim),   0.0, 1.0, 0.0)    ! y
      call glCallList(1)
      call glPopMatrix()

    !  if (gbvoice .and. .not.gbstop .and. ntim < ndat .and. ntim > 1 ) then
     !    call beepqq( int(theta(ntim)*250), 1)
      !   write(*,*) int((theta(ntim)*PI/180.0)*5000)
     ! endif

 ! call glDepthMask(.false._glboolean)
 ! if (useRGB) then
 !   call glEnable(GL_BLEND)
 ! else
 !   call glEnable(GL_POLYGON_STIPPLE)
 ! endif
 ! if (useFog) then
 !   call glDisable(GL_FOG)
 ! endif
 ! call glPushMatrix()
 ! call myShadowMatrix(groundPlane, lightPos)
 ! call glTranslatef(0.0, 0.0, 2.0)
 ! call glMultMatrixf(reshape(cubeXform,(/4,4/)))

      ! Draw ground shadow
      ! call drawCube(BLACK)      ! draw ground shadow
      ! call glPopMatrix()
!
      call glutSwapBuffers
!
      end subroutine display
!
!******************************************************************************!
!
      subroutine idle()
!
!  Locals---
      real :: t
!
!  Executable statements---
!
      if (gbstop) return
      call cpu_time(t)
      if (gfast) then
         ntim = ntim + nstp
         if (ntim > ndat) ntim = ndat
         time = t
!         call glutPostRedisplay()
      else
         if (t - time >= dt) then
            ntim = ntim + nstp
            if (ntim > ndat) ntim = ndat
            time = t
         endif
      endif
         call glutPostRedisplay()
     ! endif
!
      end subroutine idle
!
!******************************************************************************!
!
      subroutine input
!
! Purpose---
!     Read data
!
! Fortran subroutines called---
      intrinsic  cpu_time
!
! Local variables---
      integer :: ier, n
      real(4) :: dat(20)
!!      character(10) :: infile
!     
! Executable statements---
!
!     Read data 
!  
 !!     infile = 'result.txt'
!
      write(*,'(4x,a)')       'input file            : '//cgraf
!
      open(10,file=cgraf,status='old',iostat=ier)
      if (ier /= 0) then
         write(*,*) ' *** Error in init: open file error #',ier
         stop
      endif
!
      read(10,*) r
      read(10,*) h
      read(10,*) rho
      read(10,*) ndat
!
      allocate( t(ndat), PSI(ndat), THETA(ndat), PHI(ndat), &
      &  xc(ndat), yc(ndat), zc(ndat), xp(ndat), yp(ndat), stat = ier)
      if (ier /= 0) then
         write(*,*) ' *** Error in init: allocation error #',ier         
         stop
      endif
!
      do n = 1, ndat
         read(10,'(9f18.7)',iostat=ier) dat(1:9)
         t(n)     = dat(1)
         PSI(n) = DPR*dat(2)
         THETA(n) = DPR*dat(3)
         PHI(n)   = DPR*dat(4)
         xc(n)    = dat(5 )
         yc(n)    = dat(6 )
         zc(n)    = dat(7 )
         xp(n)    = dat(8 )
         yp(n)    = dat(9 )
      enddo           
!
      close(10)
!
      write(*,'(4x,3(a,f18.7))')    'r = ',r,' h = ',h,' rho = ',rho
      write(*,'(4x,a,i6)')    'number of data points : ',ndat
      write(*,'(4x,a,f8.3)')  'simulation end time   : ',t(ndat)
!
      call cpu_time( tstart)
      time = tstart
      ntim = 1
!
     ! r = 0.1
     ! h = 0.01
     ! rho = 0.0
!
      end subroutine input
!
!     *************************************************************************!
!
      subroutine keyboard( key, x, y)
!
!  Arguments---
      integer, intent(in) :: key    ! key ASCII code
      integer, intent(in) :: x, y   ! mouse coordinates (pix)
!
!  Local parameters---
!     NONE
!
!  Local variables---
      character(1) :: ch
!
!  Executable statements---
!
      select case (char(key))
      case (char(27))   ! ESC
         write(*,'(a)', advance = 'no') ' Are you really want to quit ? (Y/N) '
         read (*,'(a)') ch
         if (ch == 'Y' .or. ch == 'y') then
            stop
         endif
      case ('r','R') 
         ntim = 1
      case ('+')
         gfast = .NOT.GFAST !dt = dt/4.0
    !  case ('-')
    !     gfast = .false.
       !  dt = 4.0*dt
      CASE ('g', 'G')
         ground = .not.ground
      CASE ('s', 'S')
         gbstop = .not.gbstop
      CASE ('t', 'T')
         gbtime = .not.gbtime
      case ('a','A')
         gbauto = .not.gbauto
      case ('v','V')
         gbvoice = .not.gbvoice
      case ('0':'9')
         nstp = key - ichar('0')
         if (nstp < 1) nstp = 10
         if (nstp > 9) nstp = 10

      case default
         return
      end select
!
      call glutPostRedisplay()
!
      end subroutine keyboard
!
      subroutine text(x,y,s)
       real :: x,y
      character :: s*(*)
      character :: c
      integer :: i,lenc
  
      call glrasterpos2f(x,y)
      lenc = len(s)
      do i=1,lenc
      c = s(i:i)
      call glutbitmapcharacter(GLUT_BITMAP_TIMES_ROMAN_24, &
          ichar(c))
      end do
end subroutine text
!
!     ************************************************************************!
!
      subroutine init
!
!  Arguments---
!     NONE
!
!  Local variables---
      real(4), dimension(3) :: & ! colors for bronze from Redbook teapots
      & ambient  = (/ 0.2125,   0.1275,   0.054    /), &
      & diffuse  = (/ 0.7140,   0.4284,   0.18144  /), &
      & specular = (/ 0.393548, 0.271906, 0.166721 /)
      real(4), dimension(4) :: &
      & pos   = (/ 1.0, 1.0, 1.0, 0.0 /), &
      & white = (/ 1.0, 1.0, 1.0, 1.0 /)
!
! Executable statements---
!
!     Read data
!
      call input      
!
!     Set the display callback
!
      call glutDisplayFunc(display)
      call glutIdleFunc(idle)
      call glutKeyboardFunc( keyboard)
      call glutReshapeFunc( myRESHAPE)

!
!     Create the image
!
      call glNewList(1,GL_COMPILE)
!
!        Draw axes so we know the orientation
!
         call glColor3f( 0.0, 0.0, 0.0)
         call gAxes( 2*sngl(r))
!
!        Draw a disk
!
!        rotate so the z-axis comes out the top, x-axis out the spout
!
         call glRotated(90.0_gldouble,1.0_gldouble,0.0_gldouble,0.0_gldouble)
!
         call glMaterialfv( GL_FRONT, GL_AMBIENT,   ambient)
         call glMaterialfv( GL_FRONT, GL_DIFFUSE,   diffuse)
         call glMaterialfv( GL_FRONT, GL_SPECULAR,  specular)
         call glMaterialf ( GL_FRONT, GL_SHININESS, 25.6_glfloat)
!
!        call FillTorus( 0.1*r, 8, r, 25)
         call FillDisk( sngl(r), sngl(h), sngl(rho), 40, 4, 5)
!
      call glEndList
!
      rg = 6.0*r
      call FillGround( rg)
!
!     Set the lighting
!
      call glClearColor(0.8_glclampf, 0.8_glclampf, 0.8_glclampf, 1.0_glclampf)
      call glLightfv( GL_LIGHT0, GL_DIFFUSE, white)
      call glLightfv( GL_LIGHT0, GL_POSITION, pos)
      call glEnable ( GL_LIGHTING)
      call glEnable ( GL_LIGHT0)
      call glEnable ( GL_DEPTH_TEST)
!
      end subroutine init
!


!     ************************************************************************!
!
      subroutine FillTorus( rc, rt, numc, numt)
!
!  Arguments---
      real(4), intent(in) :: rc, rt
      integer, intent(in) :: numc, numt
!
!  Locals---
      integer :: i, j, k
      real :: s, t
      real(glfloat) x, y, z
      real twopi
!
!  Executable statements---
!
      twopi = 2*PI
!
      do i = 0, numc-1
         call glBegin(GL_QUAD_STRIP)
         do j = 0, numt
            do k = 1, 0, -1
               s = mod((i + k), numc) + 0.5
               t = mod(j, numt)
!
               x = cos(t * twopi / numt) * cos(s * twopi / numc)
               y = sin(t * twopi / numt) * cos(s * twopi / numc)
               z = sin(s * twopi / numc)
               call glNormal3f(x, y, z)

               x = (rt + rc * cos(s * twopi / numc)) * cos(t * twopi / numt)
               y = (rt + rc * cos(s * twopi / numc)) * sin(t * twopi / numt)
               z = rc * sin(s * twopi / numc)
               call glVertex3f(x, y, z)
!
            end do
         end do
         call glEnd()
      end do
!
      end subroutine fillTorus
!
!     ************************************************************************!
!
      subroutine FillTorus1( rc, rt, numc, numt)
!
!  Arguments---
      real(4), intent(in) :: rc, rt
      integer, intent(in) :: numc, numt
!
!  Locals---
      integer :: i, j, k
      real :: s, t
      real(glfloat) x, y, z
      real twopi, hpi
!
!  Executable statements---
!
      twopi = 2*PI
      hpi =PI/2
!
      do i = 0, numc-1
         call glBegin(GL_QUAD_STRIP)
         do j = 0, numt
            do k = 1, 0, -1
               s = mod((i + k), numc) + 0.5
               t = mod(j, numt)
!
               x = cos(t * twopi / numt) * cos(s * hpi / numc)
               y = sin(t * twopi / numt) * cos(s * hpi / numc)
               z = sin(s * hpi / numc)
               call glNormal3f(x, y, z)

               x = (rt + rc * cos(s * hpi / numc)) * cos(t * twopi / numt)
               y = (rt + rc * cos(s * hpi / numc)) * sin(t * twopi / numt)
               z = rc * sin(s * hpi / numc)
               call glVertex3f(x, y, z)
!
            end do
         end do
         call glEnd()
      end do
!
      end subroutine fillTorus1
!
!     *************************************************************************!
!
      subroutine fillDisk( r, h, rho, nf, nr, nz)
!
! Purpose---
!     Disk primitive
!
!  Arguments---
      real(4), intent(in) :: r   ! disk radius
      real(4), intent(in) :: h   ! disk height
      real(4), intent(in) :: rho ! filet
      integer, intent(in) :: nf  ! number of f slices
      integer, intent(in) :: nr  ! number of r slices
      integer, intent(in) :: nz  ! number of z slices
!
!  Local variables---
      real(4) :: r1, h1, fac, fach
      type(gluquadricobj), pointer :: disk_top
      type(gluquadricobj), pointer :: disk_bottom
      type(gluquadricobj), pointer :: disk_side
!
!  Executable statements---
!
      r1 = r - rho
      h1 = h - 2*rho
      fac = 1.0
      fach = 1.0
      if (rho > 0.0) then
         fac = 1.02
         fach = 1.25
      endif

!
!     Draw top
!
      disk_top    => gluNewQuadric()
      call glPushMatrix()
      call glTranslatef(0.0, 0.0, h/2)
      call gluDisk  ( disk_top,    0.0_8, dble(r1*fac), nf, nr) !nf, nr)
      call gluQuadricOrientation( disk_top, GLU_OUTSIDE)
      call gluQuadricNormals( disk_top, GLU_SMOOTH)
      call glPopMatrix()
!
!     Draw bottom
!
      disk_bottom => gluNewQuadric()
      call glPushMatrix()
      call glTranslatef(0.0, 0.0, -h/2)
      call gluQuadricOrientation( disk_bottom, GLU_INSIDE)
      call gluQuadricNormals( disk_bottom, GLU_SMOOTH)
      call gluDisk  ( disk_bottom, 0.0_8, dble(r1*fac), nf, nr)
      call glPopMatrix()
!
!     Draw side
!
      if (h1 > 0.0) then
         disk_side => gluNewQuadric()
         call glPushMatrix()
         call glTranslatef(0.0, 0.0, -fach*h1/2)
         call gluCylinder( disk_side, dble(r), dble(r), dble(fach*h1), nf, nz)
         call gluQuadricNormals( disk_side, GLU_SMOOTH)
         call glPopMatrix()
      endif
!
      if (rho <= 0.0) return
!
!     Draw up filet
!
      call glPushMatrix()
      call glTranslatef(0.0, 0.0, h1/2)
      call FillTorus1( rho, r1, 8, nf)
      call glPopMatrix()
!
!     Draw up filet
!
      call glPushMatrix()
      call glTranslatef(0.0, 0.0,-h1/2)
      call glRotatef   (180.0, 1.0, 0.0, 0.0)
      call FillTorus1( rho, r1, 8, nf)
      call glPopMatrix()
!
      end subroutine fillDisk
!
!     *************************************************************************!
!
      subroutine FillGround( rr)
!
!  Arguments---
      real(4) :: rr !,evenColor,oddColor
!
      logical, save :: initialized  = .false., &
                    usedLighting = .false.
      integer(gluint), save :: checklist = 0
      real, save :: square_normal(4) = (/0.0, 0.0, 1.0, 0.0/)
      integer i,j
      real :: w, h
!
      real(4), dimension(3) :: & ! colors for bronze from Redbook teapots
      & ambient1  = (/ 0.7, 0.7, 0.7  /), &
      & diffuse1  = (/ 0.1, 0.5, 0.8  /), &
      & specular1 = (/ 1.0, 1.0, 1.0 /)
!  Executable statements---
!
     ! if ( initialized) then
     !    call glCallList(checklist)
     !    return
     ! endif

!      if (.not. initialized ) then !.or. (usedLighting .EQV. useLighting)) then

      if (checklist == 0) then
         checklist = glGenLists(1)
      endif
      w = rr
      h = w
      call glMaterialfv( GL_FRONT, GL_AMBIENT,   ambient1)
      call glMaterialfv( GL_FRONT, GL_DIFFUSE,   diffuse1)
      call glMaterialfv( GL_FRONT, GL_SPECULAR,  specular1)
      call glMaterialf ( GL_FRONT, GL_SHININESS, 25.0_glfloat)
      call glNewList(checklist, GL_COMPILE_AND_EXECUTE)
    !  call glColor3f( 0.0, 0.5, 0.5)

!      if (useQuads) then
         call glNormal3fv(square_normal)
!         call glBegin(GL_QUADS)
!      else
          call glBegin(GL_POLYGON)
!      endif
!
      call glVertex2f(-w/2.0, -h/2.0)
      call glVertex2f( w/2.0, -h/2.0)
      call glVertex2f( w/2.0,  h/2.0)
      call glVertex2f(-w/2.0,  h/2.0)
!
      call glEnd()
      call glEndList()
      initialized = .true.
!
      end subroutine FillGround
!
      end module my_disk
