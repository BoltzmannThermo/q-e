!
! Copyright (C) 2002 CP90 group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!

#include "../include/machine.h"

subroutine errore(a,b,n)
!-----------------------------------------------------------------------
      character(len=*) a,b
      integer n
#ifdef __PARA
      include 'mpif.h'
      integer ierr
#endif
!
      write(6,1) a,b,n
    1 format(//' program ',a,':',a,'.',8x,i8,8x,'stop')
#ifdef __MPI
      call mpi_abort( MPI_COMM_WORLD, ierr, ierr)
      call mpi_finalize(ierr)
#endif
!
      stop
      end
