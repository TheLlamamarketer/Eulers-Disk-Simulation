module my_view_modifier
!
! This module provides facilities to modify the view in an OpenGL window.
! The mouse buttons and keyboard arrow keys can be used to zoom, pan,
! rotate and change the scale.  A menu or submenu can be used to select which
! buttons perform which function and to reset the view to the initial settings.
! This is limited to one window.

! William F. Mitchell
! william.mitchell@nist.gov
! Mathematical and Computational Sciences Division
! National Institute of Standards and Technology
! April, 1998
!
! To use this module:
!
! 1) put a USE view_modifier statement in any program unit that calls a
!    procedure in this module
!
! 2) set the initial operation assignments, view and scale below the
!    "Initial configuration" comment below
!
! 3) call view_modifier_init after glutCreateWindow
!    This is a function that returns integer(kind=glcint) menuid.  The menuid
!    is the ID returned by glutCreateMenu.  You can either use the view_modifier
!    menu as your menu by calling glutAttachMenu immediately after
!    view_modifier_init, as in
!       menuid = view_modifier_init()
!       call glutAttachMenu(GLUT_RIGHT_BUTTON)
!    or by using the menuid to attach a submenu to your own menu, as in
!       call glutAddSubMenu("View Modifier",menuid)
!
! 4) in any callback functions that update the display, put
!       call reset_view
!    as the first executable statement
!
! Note that view_modifier_init sets the callback functions for glutMouseFunc,
! glutMotionFunc and glutSpecialFunc, so don't call these yourself
!
! The menu allows you to select what operation is attached to the left and
! middle mouse buttons and arrow keys, reset to the initial view, and quit.
! The right mouse button should be used for the menu.
!
!
!  Modules used---
      use opengl_gl
      use opengl_glu
      use opengl_glut
!
      implicit none
      private
!
!  Public routines---
      public :: view_modifier_init, reset_view, myreshape,auto_pan
!
! Private routines---
      private :: &
           left_button_func, middle_button_func, arrow_key_func, &
           init_lookat, init_lookfrom, &
           init_xscale_factor, init_yscale_factor, init_zscale_factor, &
           angle, shift, xscale_factor, yscale_factor, zscale_factor, &
           moving_left, moving_middle, begin_left, begin_middle, &
           cart2sphere, sphere2cart, cart3D_plus_cart3D, cart3D_minus_cart3D, &
           reset_to_init, mouse, motion, arrows, &
           menu_handler, set_left_button, set_middle_button, set_arrow_keys
!
! Private parameters---
!
!     *** Vieving commands ***
!
      integer, private, parameter :: ZOOM   = 1
      integer, private, parameter :: PAN    = 2
      integer, private, parameter :: ROTATE = 3
      integer, private, parameter :: SCALEX = 4
      integer, private, parameter :: SCALEY = 5
      integer, private, parameter :: SCALEZ = 6
      integer, private, parameter :: RESET  = 10
      integer, private, parameter :: QUIT   = 11
!
!     *** Math. constants ***
!
      real(8), private, parameter :: ZERO = 0.0_8
      real(8), private, parameter :: ONE  = 1.0_8
      real(8), private, parameter :: PI   = 3.1415926535897932384626433832795_8
      real(8), private, parameter :: RPD  = PI/180.0_8
      real(8), private, parameter :: DPR  = 180.0_8/PI
!
! Type definitions---
      type, private :: cart2D ! 2D cartesian coordinates
         real(kind=gldouble) :: x, y
      end type cart2D
!
      type, private :: cart3D ! 3D cartesian coordinates
         real(kind=gldouble) :: x, y, z
      end type cart3D
!
      type, private :: sphere3D ! 3D spherical coordinates
         real(kind=gldouble) :: PSI, phi, rho
      end type sphere3D
!
! Variables---
      type(cart2D), save :: angle      ! deg
      type(cart3D), save :: shift
      real(8),      save :: xscale_factor, yscale_factor, zscale_factor
      logical,      save :: moving_left, moving_middle
      type(cart2D), save :: begin_left, begin_middle
!
      interface operator(+)
         module procedure cart3D_plus_cart3D
      end interface
!   
      interface operator(-)
         module procedure cart3D_minus_cart3D
      end interface
!
! ------- Initial configuration -------
!
! Set the initial operation performed by each button and the arrow keys.
! The operations are ZOOM, PAN, ROTATE, SCALEX, SCALEY, and SCALEZ
!
      integer, save :: left_button_func   = ROTATE
      integer, save :: middle_button_func = ZOOM
      integer, save :: arrow_key_func     = PAN
      real(8) :: xy_ratio = ONE
!
! Set the initial view as the point you are looking at, the point you are
! looking from, and the scale factors
!
      type(cart3D) :: &
         init_lookat   = cart3D(0.0_gldouble, 0.0_gldouble, 0.0_gldouble), &
         init_lookfrom = cart3D(0.5_gldouble, -1.0_gldouble, 0.25_gldouble)
!
!         init_lookfrom = cart3D(10.0_gldouble, -20.0_gldouble, 5.0_gldouble)
!
      real(kind=gldouble), parameter :: &
      init_xscale_factor = ONE, &
      init_yscale_factor = ONE, &
      init_zscale_factor = ONE

! -------- end of Initial configuration ------
!
      contains
!
      subroutine myreshape( W, H)
         integer :: w, h

         call glViewport( 0, 0, w, h)
         xy_ratio = dble(w)/dble(h)
      call glMatrixMode(GL_PROJECTION)
      call glLoadIdentity()
 !     call glFrustum( -1.0_8, 1.0_8, -1.0_8, 1.0_8, 0.1_gldouble, 200.0_gldouble)
      call gluPerspective(10.0_gldouble, xy_ratio, 0.1_gldouble, 200.0_gldouble)
      call glMatrixMode(GL_MODELVIEW)
        !  
      end subroutine myreshape

!******************************************************************************!
!
      subroutine reset_view
!
!  Purpose---
!     This routine resets the view to the current orientation and scale. It is 
!     called by myDisplay routine.
!
!  Arguments---
!     NONE
!
! FORTRAN functions called---
      intrinsic   cos, sin
!
!  Executable statements---
!
      call glMatrixMode(GL_MODELVIEW)
      call glPopMatrix()
      call glPushMatrix()
      call glLoadIdentity()
!
      call glTranslated(shift%x, shift%y, shift%z)
      call glRotated   ( angle%x, ZERO, ZERO, ONE)
      call glRotated   ( angle%y, cos(RPD*angle%x), -sin(RPD*angle%x), ZERO)
      call glTranslated(-init_lookat%x, -init_lookat%y, -init_lookat%z)
      call glScaled    (xscale_factor, yscale_factor, zscale_factor)
!
      return
!
      end subroutine reset_view
!
!******************************************************************************!
!
   function view_modifier_init() result(menuid)
!
! Purpose---
!     This initializes the view modifier variables and sets initial view.
!     It should be called immediately after glutCreateWindow
!
!  Result---        
      integer(kind=glcint) :: menuid
!
!  Local variables---
      integer(kind=glcint) :: button_left, button_middle, arrow_keys
!
!  Executable statements---
!
!     set the callback functions
!
      call glutMouseFunc(mouse)
      call glutMotionFunc(motion)
      call glutSpecialFunc(arrows)
!
!     create the menu
!
      button_left = glutCreateMenu(set_left_button)
      call glutAddMenuEntry("rotate",  ROTATE)
      call glutAddMenuEntry("zoom",    ZOOM)
      call glutAddMenuEntry("pan",     PAN)
!      call glutAddMenuEntry("scale x", SCALEX)
!      call glutAddMenuEntry("scale y", SCALEY)
!      call glutAddMenuEntry("scale z", SCALEZ)
!
!      button_middle = glutCreateMenu(set_middle_button)
!      call glutAddMenuEntry("rotate",  ROTATE)
!      call glutAddMenuEntry("zoom",    ZOOM)
!      call glutAddMenuEntry("pan",     PAN)
!      call glutAddMenuEntry("scale x", SCALEX)
!      call glutAddMenuEntry("scale y", SCALEY)
!      call glutAddMenuEntry("scale z", SCALEZ)
!
!      arrow_keys = glutCreateMenu(set_arrow_keys)
!      call glutAddMenuEntry("rotate",  ROTATE)
!      call glutAddMenuEntry("zoom",    ZOOM)
!      call glutAddMenuEntry("pan",     PAN)
!      call glutAddMenuEntry("scale x", SCALEX)
!      call glutAddMenuEntry("scale y", SCALEY)
!      call glutAddMenuEntry("scale z", SCALEZ)
!
      menuid = glutCreateMenu(menu_handler)
      call glutAddSubMenu  ("left mouse button",  button_left)
!      call glutAddSubMenu  ("middle mouse button",button_middle)
!      call glutAddSubMenu  ("arrow keys",arrow_keys)
      call glutAddMenuEntry("reset to initial view",RESET)
      call glutAddMenuEntry("quit",QUIT)
!
!     set the perspective
!
      call glMatrixMode(GL_PROJECTION)
 !     call glFrustum( -1.0_8, 1.0_8, -1.0_8, 1.0_8, 0.1_gldouble, 200.0_gldouble)
      call gluPerspective(10.0_gldouble, xy_ratio, 0.1_gldouble, 200.0_gldouble)
!
!     set the initial view
!
      call glPushMatrix
      call reset_to_init
!
end function view_modifier_init
!
!******************************************************************************!
!
!                             *** Private routines ***
!
!******************************************************************************!
!
      subroutine reset_to_init
!
!  Purpose---
!     This resets the view to the initial configuration
!
!  Local variables---
      type(sphere3D) :: slookfrom
!
!  Executable statements---
!
init_lookat%x=0.0_8
init_lookat%y=0.0_8
init_lookat%z=0.0_8
      slookfrom     = cart2sphere(init_lookfrom-init_lookat)
      angle%x       = -DPR*slookfrom%PSI - 90.0_8
      angle%y       = -DPR*slookfrom%phi
      shift%x       = ZERO
      shift%y       = ZERO
      shift%z       = -slookfrom%rho
      xscale_factor = init_xscale_factor
      yscale_factor = init_yscale_factor
      zscale_factor = init_zscale_factor
!
      call glutPostRedisplay
!
      end subroutine reset_to_init
!
!******************************************************************************!
!
subroutine mouse(button, state, x, y)
!          
integer(kind=glcint), intent(in out) :: button, state, x, y

! This gets called when a mouse button changes
 
  if (button == GLUT_LEFT_BUTTON .and. state == GLUT_DOWN) then
    moving_left = .true.
    begin_left = cart2D(x,y)
  endif
  if (button == GLUT_LEFT_BUTTON .and. state == GLUT_UP) then
    moving_left = .false.
  endif
  if (button == GLUT_MIDDLE_BUTTON .and. state == GLUT_DOWN) then
    moving_middle = .true.
    begin_middle = cart2D(x,y)
  endif
  if (button == GLUT_MIDDLE_BUTTON .and. state == GLUT_UP) then
    moving_middle = .false.
  endif
end subroutine mouse
!
!******************************************************************************!
!
      subroutine motion(x, y)
!        
! Arguments--- 
integer(kind=glcint), intent(in out) :: x, y

! This gets called when the mouse moves

integer :: button_function
type(cart2D) :: begin
real(kind=gldouble) :: factor

! Determine and apply the button function

if (moving_left) then
   button_function = left_button_func
   begin = begin_left
else if(moving_middle) then
   button_function = middle_button_func
   begin = begin_middle
end if

select case(button_function)
case (ZOOM)
   if (y < begin%y) then
      factor = ONE/(ONE + .002_gldouble*(begin%y-y))
   else if (y > begin%y) then
      factor = ONE + .002_gldouble*(y-begin%y)
   else
      factor = ONE
   end if
   shift%z = factor*shift%z
case (PAN)
   shift%x = shift%x + .01*(x - begin%x)
   shift%y = shift%y - .01*(y - begin%y)
case (ROTATE)
   angle%x = angle%x + (x - begin%x)
   angle%y = angle%y + (y - begin%y)
case (SCALEX)
   if (y < begin%y) then
      factor = ONE + .002_gldouble*(begin%y-y)
   else if (y > begin%y) then
      factor = ONE/(ONE + .002_gldouble*(y-begin%y))
   else
      factor = ONE
   end if
   xscale_factor = xscale_factor * factor
case (SCALEY)
   if (y < begin%y) then
      factor = ONE + .002_gldouble*(begin%y-y)
   else if (y > begin%y) then
      factor = ONE/(ONE + .002_gldouble*(y-begin%y))
   else
      factor = ONE
   end if
   yscale_factor = yscale_factor * factor
case (SCALEZ)
   if (y < begin%y) then
      factor = ONE + .002_gldouble*(begin%y-y)
   else if (y > begin%y) then
      factor = ONE/(ONE + .002_gldouble*(y-begin%y))
   else
      factor = ONE
   end if
   zscale_factor = zscale_factor * factor
end select

! update private variables and redisplay

if (moving_left) then
   begin_left = cart2D(x,y)
else if(moving_middle) then
   begin_middle = cart2D(x,y)
endif

if (moving_left .or. moving_middle) then
   call glutPostRedisplay
endif

return
end subroutine motion
!
!******************************************************************************!
!
subroutine arrows(key, x, y)
!
! Purpose---
!  This routine handles the arrow key operations
!
! Arguments---        
   integer(glcint), intent(in out) :: key, x, y
   real(kind=gldouble) :: factor
!
! Executable statements---
!
   select case(arrow_key_func)
   case(ZOOM)
      select case(key)
      case(GLUT_KEY_DOWN)
         factor = ONE + .02_gldouble
      case(GLUT_KEY_UP)
         factor = ONE/(ONE + .02_gldouble)
      case default
         factor = ONE
      end select
      shift%z = factor*shift%z
   case(PAN)
      select case(key)
      case(GLUT_KEY_LEFT)
         shift%x = shift%x - .02
      case(GLUT_KEY_RIGHT)
         shift%x = shift%x + .02
      case(GLUT_KEY_DOWN)
         shift%y = shift%y - .02
      case(GLUT_KEY_UP)
         shift%y = shift%y + .02
      end select
   case(ROTATE)
      select case(key)
      case(GLUT_KEY_LEFT)
         angle%x = angle%x - ONE
      case(GLUT_KEY_RIGHT)
         angle%x = angle%x + ONE
      case(GLUT_KEY_DOWN)
         angle%y = angle%y + ONE
      case(GLUT_KEY_UP)
         angle%y = angle%y - ONE
      end select
   case(SCALEX)
      select case(key)
      case(GLUT_KEY_DOWN)
         factor = ONE/(ONE + .02_gldouble)
      case(GLUT_KEY_UP)
         factor = ONE + .02_gldouble
      case default
         factor = ONE
      end select
      xscale_factor = xscale_factor * factor
   case(SCALEY)
      select case(key)
      case(GLUT_KEY_DOWN)
         factor = ONE/(ONE + .02_gldouble)
      case(GLUT_KEY_UP)
         factor = ONE + .02_gldouble
      case default
         factor = ONE
      end select
         yscale_factor = yscale_factor * factor
   case(SCALEZ)
      select case(key)
      case(GLUT_KEY_DOWN)
         factor = ONE/(ONE + .02_gldouble)
      case(GLUT_KEY_UP)
         factor = ONE + .02_gldouble
      case default
         factor = ONE
      end select
      zscale_factor = zscale_factor * factor
   end select
!   
   call glutPostRedisplay
!
end subroutine arrows
!
!******************************************************************************!
!
subroutine menu_handler(value)
!
! Purpose---
!  This routine handles the first level entries in the menu
!
! Arguments---      
   integer(kind=glcint), intent(in out) :: value
!
   select case(value)
   case(RESET)
      call reset_to_init
   case(QUIT)
      stop
   end select
!
end subroutine menu_handler
!
!******************************************************************************!
!
subroutine set_left_button(value)
!          
integer(kind=glcint), intent(in out) :: value

! This routine sets the function of the left button as given by menu selection

left_button_func = value

return
end subroutine set_left_button
!
!******************************************************************************!
!
subroutine set_middle_button(value)
!        
integer(kind=glcint), intent(in out) :: value

! This routine sets the function of the middle button as given by menu selection

middle_button_func = value

return
end subroutine set_middle_button
!
!******************************************************************************!
!
subroutine set_arrow_keys(value)
!
   integer(kind=glcint), intent(in out) :: value
!
! This routine sets the function of the arrow keys as given by menu selection
!
   arrow_key_func = value
!
   return
end subroutine set_arrow_keys
!
!******************************************************************************!
!
function sphere2cart(spoint) result(cpoint)
!   
   type(sphere3D), intent(in) :: spoint
   type(cart3D) :: cpoint
!
! This converts a 3D point from spherical to cartesean coordinates
!
   real(kind=gldouble) :: t,p,r
!
   t=spoint%PSI
   p=spoint%phi
   r=spoint%rho
!
   cpoint%x = r*cos(t)*sin(p)
   cpoint%y = r*sin(t)*sin(p)
   cpoint%z = r*cos(p)
!
   return
end function sphere2cart
!
!******************************************************************************!
!
function cart2sphere(cpoint) result(spoint)
! 
   type(cart3D), intent(in) :: cpoint
   type(sphere3D) :: spoint

! This converts a 3D point from cartesean to spherical coordinates
!
   real(kind=gldouble) :: x,y,z
!
   x=cpoint%x
   y=cpoint%y
   z=cpoint%z
!
   spoint%rho = sqrt(x*x+y*y+z*z)
   if (x==0.0_gldouble .and. y==0.0_gldouble) then
      spoint%PSI = 0.0_gldouble
   else
      spoint%PSI = atan2(y,x)
   end if
   if (spoint%rho == 0.0_gldouble) then
      spoint%phi = 0.0_gldouble
   else
      spoint%phi = acos(z/spoint%rho)
   endif
!
   return
end function cart2sphere
!
!******************************************************************************!
!
function cart3D_plus_cart3D(cart1,cart2) result(cart3)
!
   type(cart3D), intent(in) :: cart1, cart2
   type(cart3D) :: cart3
!
! Compute the sum of two 3D cartesean points
!
   cart3%x = cart1%x + cart2%x
   cart3%y = cart1%y + cart2%y
   cart3%z = cart1%z + cart2%z
!
   return
end function cart3D_plus_cart3D
!
!******************************************************************************!
!
function cart3D_minus_cart3D(cart1,cart2) result(cart3)
!  
   type(cart3D), intent(in) :: cart1, cart2
   type(cart3D) :: cart3
!
! Compute the difference of two 3D cartesean points
!
   cart3%x = cart1%x - cart2%x
   cart3%y = cart1%y - cart2%y
   cart3%z = cart1%z - cart2%z
!
   return
end function cart3D_minus_cart3D
!
!******************************************************************************!
!
!******************************************************************************!
!
      subroutine auto_pan( x, y, z)
!
!  Purpose---
!     This routine resets the view to the current orientation and scale. It is 
!     called by myDisplay routine.
!
!  Arguments---
real(4) :: x, y, z
!
! FORTRAN functions called---
      intrinsic   cos, sin
!
!  Executable statements---
!
init_lookat%x=x
init_lookat%y=y 
init_lookat%z=z
      call glMatrixMode(GL_MODELVIEW)
      call glPopMatrix()
      call glPushMatrix()
      call glLoadIdentity()
!
      call glTranslated(shift%x, shift%y, shift%z)
      call glRotated   ( angle%x, ZERO, ZERO, ONE)
      call glRotated   ( angle%y, cos(RPD*angle%x), -sin(RPD*angle%x), ZERO)
      call glTranslated(-init_lookat%x, -init_lookat%y, -init_lookat%z)
      call glScaled    (xscale_factor, yscale_factor, zscale_factor)
!
      return
!
      end subroutine auto_pan
end module my_view_modifier
