      module my_primitives
!
! Modules used---
      use opengl_gl
      use opengl_glu
      use opengl_glut
!
      implicit none
      private
      save
!
! Public routines---
      public :: gAxes
      public :: gCircle
      public :: gLine
      public :: gPolyline
!
! Interfaces---
!
      interface gAxes
         module procedure d3Axes !, drawLine3d
      end interface
!
!
      interface gCircle
         module procedure drawCircle2d, drawCircle3d
      end interface
!
      interface gLine
         module procedure drawLine2d, drawLine3d
      end interface
!
      interface gPolyline
         module procedure drawPolyline2d, drawPolyline3d
      end interface
!
! Private parameters---
!
!     *** Mathematical constatnts ***
!
      real(8), private, parameter :: ZERO  = 0.0_8
      real(8), private, parameter :: ONE   = 1.0_8
      real(8), private, parameter :: PI    = 3.1415926535897932384626433832795_8
      real(8), private, parameter :: HPI   = 1.5707963267948966192313216916398
      real(8), private, parameter :: TWOPI = 6.283185307179586476925286766559_8
      real(8), private, parameter :: RPD   = 0.017453292519943295769236907684886_8
      real(8), private, parameter :: DPR   = 57.295779513082320876798154814105_8
!
      contains
!
!     *************************************************************************!
!
      subroutine d3Axes( size)
!
!  Arguments---
      real(4), intent(in) :: size
!
!  Local variables---      
      real(4) :: size1 , size2
!
!  Executable statements---
!
      size1 = (2.1*size)/2.0
      size2 = (0.1*size)/2.0
!
      call glBegin(GL_LINES)
!
!        Draw base
!
         call glVertex3f( 0.0,  0.0,  0.0)
         call glVertex3f(size,  0.0,  0.0)
         call glVertex3f( 0.0,  0.0,  0.0)
         call glVertex3f( 0.0, size,  0.0)
         call glVertex3f( 0.0,  0.0,  0.0)
         call glVertex3f( 0.0,  0.0, size)
!
!        Draw crude x, y and z to label the axes
!
         call glVertex3f( size1,-size2, size2) ! X
         call glVertex3f( size1, size2,-size2)
         call glVertex3f( size1,-size2,-size2)
         call glVertex3f( size1, size2, size2)
!
         call glVertex3f( size2, size1, size2) ! Y
         call glVertex3f(   0.0, size1,   0.0)
         call glVertex3f(-size2, size1, size2)
         call glVertex3f( size2, size1,-size2)
!
         call glVertex3f(-size2, size2, size1) ! Z
         call glVertex3f( size2, size2, size1)
         call glVertex3f( size2, size2, size1)
         call glVertex3f(-size2,-size2, size1)
         call glVertex3f(-size2,-size2, size1)
         call glVertex3f( size2,-size2, size1)
!
      call glEnd
!
      end subroutine d3Axes
!
!     *************************************************************************!
!
      subroutine drawCircle2d( r, xc, yc, npts)
!
!  Purpose---
!     Generate vertexs for circle
!
!  Arguments---
      real(4), intent(in) :: xc, yc, r
!
! Optional arguments---
      integer, optional, intent(in) :: npts   ! Number of points
!      !
!  FORTRAN fubction called---
      intrinsic sin, cos
!
!  Local variables---
      integer :: n, npt
      real(4) :: sint, cost, dt, ts, te, xb, yb, xcurr, ycurr, xtemp
!
!  Executable statements---
!
      npt = 360/5
      if (present(npts)) then
         if (npts > 0) npt = npts
      endif
!
      ts  = ZERO
      dt  = TWOPI/npt !(te - ts)/(nip1-1)
!
      sint  = 0.0 !sin(ts)
      cost  = 1.0 !cos(ts) 
      xcurr = r*cost
      ycurr = r*sint
      sint  = sin(dt)
      cost  = sqrt(1.0 - sint*sint)
!
      call glBegin( GL_LINE_LOOP)
!
         do n = 1,npt
            xb = xc + xcurr
            yb = yc + ycurr
!
            call glVertex2f( xb, yb)
!
            xtemp = cost*xcurr - sint*ycurr
            ycurr = sint*xcurr + cost*ycurr
            xcurr = xtemp
         enddo
!
      call glEnd()
!
      end subroutine drawCircle2d
!
!     *************************************************************************!
!
      subroutine drawCircle3d( r, xc, yc, zc, upx, upy, upz, npts)
!
!  Purpose---
!     Generate vertexs for circle
!
!  Arguments---
      real(4), intent(in) :: xc, yc, zc, r   ! Center point and radius
      real(4), intent(in) :: upx, upy, upz   ! Plane normal
!
! Optional arguments---
      integer, optional, intent(in) :: npts  ! Number of points
!
!  FORTRAN fubction called---
      intrinsic sin, cos
!
!  Local variables---
      integer :: n, npt
      real(4) :: sint, cost, dt, ts, te, xb, yb, xcurr, ycurr, xtemp
!
!  Executable statements---
!
      npt = 360/5
      if (present(npts)) then
         if (npts > 0) npt = npts
      endif
!
      ts  = ZERO
      dt  = TWOPI/npt !(te - ts)/(nip1-1)
!
      sint  = 0.0 !sin(ts)
      cost  = 1.0 !cos(ts) 
      xcurr = r*cost
      ycurr = r*sint
      sint  = sin(dt)
      cost  = sqrt(1.0 - sint*sint)
!
      call glMatrixMode( GL_MODELVIEW)
      call glPushMatrix()
      call glLoadIdentity()
      call glRotated( -dble(upx), 0.0_8, 0.0_8, 1.0_8)
      call glRotated( -dble(upy), 0.0_8, 0.0_8, 1.0_8)
      call glRotated( -dble(upz), 0.0_8, 0.0_8, 1.0_8)
      call glTranslated( dble( xc), dble( yc), dble( zc))
!
      call glBegin( GL_LINE_LOOP)
!
         do n = 1,npt
            xb = xcurr
            yb = ycurr
!
            call glVertex2f( xb, yb)
!
            xtemp = cost*xcurr - sint*ycurr
            ycurr = sint*xcurr + cost*ycurr
            xcurr = xtemp
         enddo
!
      call glEnd()
      call glPopMatrix()
!
      end subroutine drawCircle3d
!
!     *************************************************************************!
!
      subroutine drawLine2d( x1, y1, x2, y2)
!
!  Arguments---
      real(4), intent(in) :: x1, y1, x2, y2
!
!  Executable statements---
!
      call glBegin( GL_LINES)
         call glVertex2f( x1, y1)
         call glVertex2f( x2, y2)
      call glEnd
!
      end subroutine drawLine2d
!
!     *************************************************************************!
!
      subroutine drawLine3d( x1, y1, z1, x2, y2, z2)
!
!  Arguments---
      real(4), intent(in) :: x1, y1, z1, x2, y2, z2
!
!  Executable statements---
!
      call glBegin( GL_LINES)
         call glVertex3f( x1, y1, z1)
         call glVertex3f( x2, y2, z2)
      call glEnd
!
      end subroutine drawLine3d
!
!     *************************************************************************!
!
      subroutine drawPolyline2d( npt, x, y)
!
!  Arguments---
      integer, intent(in) :: npt
      real(4), intent(in) :: x(*), y(*)
!
!  Local variables---
      integer :: i
!
!  Executable statements---
!
      call glBegin( GL_LINE_STRIP)
         do i = 1, npt
            call glVertex2f( x(i),y(i))
         enddo
      call glEnd
!
      end subroutine drawPolyline2d
!
!     *************************************************************************!
!
      subroutine drawPolyline3d( npt, x, y, z)
!
!  Arguments---
      integer, intent(in) :: npt
      real(4), intent(in) :: x(*), y(*), z(*)
!
!  Local variables---
      integer :: i
!
!  Executable statements---
!
      call glBegin( GL_LINE_STRIP)
         do i = 1, npt
            call glVertex3f( x(i), y(i), z(i))
         enddo
      call glEnd
!
      end subroutine drawPolyline3d
!
!     *************************************************************************!
!
      end module my_primitives