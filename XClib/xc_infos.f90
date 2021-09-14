!
! Copyright (C) 2021 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!============================================================================
!============================================================================
PROGRAM xc_infos
  !==========================================================================
  !! Provides infos on the input DFTs (both QE and Libxc).
  !
  ! --- To be run on a single processor ---
  !
  USE kind_l,               ONLY: DP
  USE xc_lib,               ONLY: xclib_set_dft_from_name, xclib_get_ID, &
                                  xclib_dft_is_libxc, xclib_init_libxc,  &
                                  xclib_finalize_libxc
  USE qe_dft_list
  USE dft_setting_params,   ONLY: ishybrid, exx_fraction, screening_parameter, &
                                  gau_parameter
  USE dft_setting_routines, ONLY: xclib_set_auxiliary_flags
  USE xclib_utils_and_para, ONLY: stdout
#if defined(__LIBXC)
#include "xc_version.h"
  USE xc_f03_lib_m
  USE dft_setting_params,   ONLY: xc_func, xc_info
#endif
  !
  IMPLICIT NONE
  !
  CHARACTER(LEN=120) :: lxc_kind, lxc_family
  CHARACTER(LEN=150) :: dft_r
  CHARACTER(LEN=10)  :: dft_n
  INTEGER :: n_ext, id(6)
  INTEGER :: i, ii
#if defined(__LIBXC)
#if (XC_MAJOR_VERSION>5)
  !workaround to keep compatibility with libxc develop version
  INTEGER, PARAMETER :: XC_FAMILY_HYB_GGA  = -10
  INTEGER, PARAMETER :: XC_FAMILY_HYB_MGGA = -11 
#endif
#endif
  !
  !-------- Input var -----------------------
  CHARACTER(LEN=80) :: dft
  !
  !---------- DFT infos -------------------------
  INTEGER :: iexch, icorr, igcx, igcc, imeta, imetac, idx
  LOGICAL :: is_libxc(6)
  !
  dft = 'none'
  !
  WRITE (*,'(/,1x,a)', ADVANCE='no') "Insert DFT name:  "
  READ(*,'(A)') dft
  !
  !==========================================================================
  ! PRINT DFT INFOS
  !==========================================================================
  !
  CALL xclib_set_dft_from_name( dft )
  !
  iexch = xclib_get_ID('LDA','EXCH')
  is_libxc(1) = xclib_dft_is_libxc('LDA','EXCH')
  icorr = xclib_get_ID('LDA','CORR')
  is_libxc(2) = xclib_dft_is_libxc('LDA','CORR')
  igcx = xclib_get_ID('GGA','EXCH')
  is_libxc(3) = xclib_dft_is_libxc('GGA','EXCH')
  igcc = xclib_get_ID('GGA','CORR')
  is_libxc(4) = xclib_dft_is_libxc('GGA','CORR')
  imeta = xclib_get_ID('MGGA','EXCH')
  is_libxc(5) = xclib_dft_is_libxc('MGGA','EXCH')
  imetac = xclib_get_ID('MGGA','CORR')
  is_libxc(6) = xclib_dft_is_libxc('MGGA','CORR')
  !
  WRITE(stdout,*) " "
  WRITE(stdout,*) "=================================== "//CHAR(10)//" "
  WRITE(stdout,*) "The inserted XC functional is a composition of the &
                  &following terms:"  
  WRITE(stdout,*) CHAR(10)//"LDA"
  WRITE(stdout,121) iexch, TRIM(xc_library(is_libxc(1),iexch)), &
                    icorr, TRIM(xc_library(is_libxc(2),icorr)) 
  WRITE(stdout,*) CHAR(10)//"GGA"
  WRITE(stdout,121) igcx,  TRIM(xc_library(is_libxc(3),igcx)),  &
                    igcc,  TRIM(xc_library(is_libxc(4),igcc))
  WRITE(stdout,*) CHAR(10)//"MGGA"  
  WRITE(stdout,121) imeta, TRIM(xc_library(is_libxc(5),imeta)), &
                    imetac,TRIM(xc_library(is_libxc(6),imetac))
  WRITE(stdout,*) " "  
  WRITE(stdout,*) "============== "
  !  
#if defined(__LIBXC)
  IF (xclib_dft_is_libxc('ANY')) CALL xclib_init_libxc( 1, .FALSE. )  
#endif
  !
  id(1) = iexch ; id(2) = icorr
  id(3) = igcx  ; id(4) = igcc
  id(5) = imeta ; id(6) = imetac
  !
  CALL xclib_set_auxiliary_flags( .FALSE. )
  !
  DO i = 1, 6
    idx = id(i)
    !
    IF (.NOT.is_libxc(i) .AND. idx/=0) THEN
      !
      SELECT CASE( i )
      CASE( 1 ) 
        WRITE(lxc_kind, '(a)') 'EXCHANGE'
        WRITE(lxc_family,'(a)') "LDA"
        dft_n = dft_LDAx_name(idx)
        dft_r = dft_LDAx_ref(idx)
      CASE( 2 )
        WRITE(lxc_kind, '(a)') 'CORRELATION'
        WRITE(lxc_family,'(a)') "LDA"
        dft_n = dft_LDAc_name(idx)
        dft_r = dft_LDAc_ref(idx)
      CASE( 3 )
        WRITE(lxc_kind, '(a)') 'EXCHANGE'
        WRITE(lxc_family,'(a)') "GGA"
        dft_n = dft_GGAx_name(idx)
        dft_r = dft_GGAx_ref(idx)
      CASE( 4 )
        WRITE(lxc_kind, '(a)') 'CORRELATION'
        WRITE(lxc_family,'(a)') "GGA"
        dft_n = dft_GGAc_name(idx)
        dft_r = dft_GGAc_ref(idx)
      CASE( 5 )
        WRITE(lxc_kind, '(a)') 'EXCHANGE+CORRELATION'
        WRITE(lxc_family,'(a)') "MGGA"
        dft_n = dft_MGGA_name(idx)
        dft_r = dft_MGGA_ref(idx)
      END SELECT
      !
      WRITE(stdout,*) CHAR(10)
      WRITE(*,'(i1,". Functional with ID:", i3 )') i, idx
      WRITE(stdout, '(" - Name:   ",a)') TRIM(dft_n)
      WRITE(stdout, '(" - Family: ",a)') TRIM(lxc_family)
      WRITE(stdout, '(" - Kind:   ",a)') TRIM(lxc_kind)
      n_ext = 0
      IF ( ishybrid .OR. (i==3 .AND. idx==12) .OR. (i==3 .AND. idx==20) ) n_ext = 1
      IF ( n_ext/=0 ) THEN
        WRITE(stdout, '(" - External parameters:")')
        IF ( ishybrid ) WRITE(stdout,*) '   exx_fraction (default)= ', exx_fraction
        IF ( i==3 .AND. idx==12 ) WRITE(stdout,*) '   screening_parameter (default)= ',&
                                                  screening_parameter
        IF ( i==3 .AND. idx==20 ) WRITE(stdout,*) '   gau_parameter (default)= ',      &
                                                  gau_parameter
      ELSE
        WRITE(stdout, '(" - External parameters: NONE")')
      ENDIF
      WRITE(stdout, '(" - Reference(s):")')
      WRITE(*,'(a,i1,2a)') '    [',1,'] ', TRIM(dft_r) 
      !
#if defined(__LIBXC)
      !
    ELSEIF (is_libxc(i)) THEN    
      !  
      SELECT CASE( xc_f03_func_info_get_kind(xc_info(i)) )  
      CASE( XC_EXCHANGE )  
        WRITE(lxc_kind, '(a)') 'EXCHANGE'  
      CASE( XC_CORRELATION )  
        WRITE(lxc_kind, '(a)') 'CORRELATION'  
      CASE( XC_EXCHANGE_CORRELATION )  
        WRITE(lxc_kind, '(a)') 'EXCHANGE+CORRELATION'  
      CASE( XC_KINETIC )  
        WRITE(lxc_kind, '(a)') 'KINETIC ENERGY FUNCTIONAL - currently not available&  
                               &in QE.'  
      CASE DEFAULT  
        WRITE(lxc_kind, '(a)') 'UNKNOWN'
      END SELECT  
      !  
      SELECT CASE( xc_f03_func_info_get_family(xc_info(i)) )  
      CASE( XC_FAMILY_LDA )  
        WRITE(lxc_family,'(a)') "LDA"
      CASE( XC_FAMILY_GGA )
        WRITE(lxc_family,'(a)') "GGA"
      CASE( XC_FAMILY_HYB_GGA )
        WRITE(lxc_family,'(a)') "Hybrid GGA"
      CASE( XC_FAMILY_MGGA )
        WRITE(lxc_family,'(a)') "MGGA"
      CASE( XC_FAMILY_HYB_MGGA )
        WRITE(lxc_family,'(a)') "Hybrid MGGA"
      CASE DEFAULT
        WRITE(lxc_family,'(a)') "UNKNOWN"
      END SELECT
      !
      WRITE(stdout,*) CHAR(10)
      WRITE(*,'(i1,". Functional with ID: ", i3 )') i, idx
      WRITE(stdout, '(" - Name:   ",a)') TRIM(xc_f03_func_info_get_name(xc_info(i)))
      WRITE(stdout, '(" - Family: ",a)') TRIM(lxc_family)
      WRITE(stdout, '(" - Kind:   ",a)') TRIM(lxc_kind)  
      n_ext = xc_f03_func_info_get_n_ext_params( xc_info(i) )
      IF ( n_ext/=0 ) THEN 
        WRITE(stdout, '(" - External parameters: ",i3)') n_ext
        DO ii = 0, n_ext-1
          WRITE(stdout, '("  ",i3,") ",a)') ii,&  
            TRIM(xc_f03_func_info_get_ext_params_description(xc_info(i), ii))  
          WRITE(stdout,*) '      Default value: ', &  
                 xc_f03_func_info_get_ext_params_default_value(xc_info(i), ii)  
        ENDDO
      ELSE
        WRITE(stdout, '(" - External parameters: NONE")')
      ENDIF
      WRITE(stdout, '(" - Reference(s):")') 
      ii = 0  
      DO WHILE( ii >= 0 )  
        WRITE(*,'(a,i1,2a)') '    [',ii+1,'] ',TRIM(xc_f03_func_reference_get_ref( &  
                                  xc_f03_func_info_get_references(xc_info(i), ii)))  
      ENDDO
#endif
      !
    ENDIF
  ENDDO  
  !  
#if defined(__LIBXC)
  IF (xclib_dft_is_libxc('ANY')) CALL xclib_finalize_libxc()  
#endif
  !
  WRITE(stdout,*) CHAR(10)//" "
  !
  121 FORMAT( 'Exchange ID: ', i3, ', Library: ', a, ' ;  Correlation ID: ', i3, ', Library: ',a )
  !
  STOP
  !
 CONTAINS
  !
  CHARACTER(11) FUNCTION xc_library( islibxc, idxc )
    !
    LOGICAL, INTENT(IN) :: islibxc
    INTEGER, INTENT(IN) :: idxc
    !
    xc_library = ''
    IF (idxc /= 0) THEN
      IF ( islibxc ) THEN
        xc_library = 'Libxc'
      ELSE
        xc_library = 'QE_internal'
      ENDIF
    ELSE
      xc_library = 'none'
    ENDIF
    !
    RETURN
    !
  END FUNCTION
  !
END PROGRAM xc_infos
