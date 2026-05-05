      subroutine post
!
! Purpose---
!     Read data from result file. Form animation file.
!
! Modules used---
      use disk_data, only: cresf, cgraf, r,h,rho
!
! Fortran subroutines called---
!
! Local variables---
      integer :: ier, n
      real(8) :: dat(23)
!     
! Executable statements---
!
!
      open(10,file=cresf,status='old',iostat=ier)
      if (ier /= 0) then
         write(*,*) ' *** Error in cpost: open file error #',ier
         stop
      endif
!
      ndat = 0
      read(10,'(4f18.7)',iostat=ier) ! head
      do  
         read(10,'(4f18.7)',iostat=ier) dat(1:4)
         if (ier == -1) exit
         if (ier /= 0) then
            write(*,*) ' *** Error in init: read file error #',ier         
            stop
         endif
         ndat = ndat + 1
      enddo
      close(10)
!
      open(10,file=cresf,status='old',iostat=ier)
      open(11,file=cgraf,status='unknown',iostat=ier)
      write(11,*) r
      write(11,*) h
      write(11,*) rho
      write(11,*) ndat
      read(10,'(4f12.6)',iostat=ier) ! head
      do n = 1, ndat
         read(10,'(15f18.7)',iostat=ier) dat(1:15)
         write(11,'(9f18.7)') dat(1:4),dat(11:15)
      enddo           
!
      close(10)
      close(11)
!
      end subroutine post
