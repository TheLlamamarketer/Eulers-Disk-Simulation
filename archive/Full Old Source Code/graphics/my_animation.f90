      subroutine my_animation
!
! Modules used---
      use opengl_glut
      use my_view_modifier
      use my_disk
!
      implicit none
!
! Variables---
      integer :: winid, menuid
      integer :: windW = 500, windH = 500, windX = 100, windY = 100
!
! Executable statements---
!
!     Initializations
!
      call glutInit
      call glutInitDisplayMode(ior(GLUT_DOUBLE,ior(GLUT_RGB,GLUT_DEPTH)))
      call glutInitWindowSize(windW, windH)
      call glutInitWindowPosition (windX, windY)
!
!     Create a window
!
      winid = glutCreateWindow("Euler's Disk")
      menuid = view_modifier_init()
      call glutAttachMenu(GLUT_RIGHT_BUTTON)
!
!     Set the display callback
!
!      call glutDisplayFunc(display)
!      call glutIdleFunc(idle)
!      call glutKeyboardFunc( keyboard)
!
!     Initialize disk
!
      call init
!
!     Enter infinite loop
!
      call glutMainLoop
!
      end subroutine my_animation

