!
! Copyright (C) 2003-2013 Quantum ESPRESSO and Wannier90 groups
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
! pw2wannier was written by Stefano de Gironcoli
! with later additions by
! Jonathan Yates - spinors
! Arash Mostofi - gamma point and transport things
! Timo Thonhauser, Graham Lopez, Ivo Souza
!         uHu, uIu terms for orbital magnetisation
! please send bugs and comments to
! Jonathan Yates and Arash Mostofi
! Takashi Koretsune and Florian Thoele -- noncollinear and USPPs
! Valerio Vitale - Selected columns of density matrix (SCDM)
! Jae-Mo Lihm - SCDM with noncollinear
! Ji Hoon Ryoo, Minsu Ghim - sHu, sIu terms for spin Hall conductivity
!
! NOTE: old_spinor_proj is still available for compatibility with old
!       nnkp files but should be removed soon.
!
!
module wannier
   USE kinds, only : DP
   !integer, allocatable :: nnb(:)       ! #b  (ik)
   integer              :: nnb          ! #b
   integer, allocatable :: kpb(:,:)     ! k+b (ik,ib)
   integer, allocatable :: g_kpb(:,:,:) ! G_k+b (ipol,ik,ib)
   integer, allocatable :: ig_(:,:)     ! G_k+b (ipol,ik,ib)
   integer, allocatable :: lw(:,:), mw(:,:) ! l and m of wannier (16,n_wannier)
   integer, allocatable :: num_sph(:)   ! num. func. in lin. comb., (n_wannier)
   logical, allocatable :: excluded_band(:)
   ! begin change Lopez, Thonhauser, Souza
   integer  :: iun_nnkp,iun_mmn,iun_amn,iun_band,iun_spn,iun_plot,iun_parity,&
        nnbx,nexband,iun_uhu,&
        iun_uIu,& !ivo
   ! end change Lopez, Thonhauser, Souza
        iun_sHu, iun_sIu ! shc
   integer  :: n_wannier !number of WF
   integer  :: n_proj    !number of projection
   complex(DP), allocatable :: gf(:,:)  ! guding_function(npwx,n_wannier)
   complex(DP), allocatable :: gf_spinor(:,:)
   complex(DP), allocatable :: sgf_spinor(:,:)
   integer               :: ispinw, ikstart, ikstop, iknum
   character(LEN=15)     :: wan_mode    ! running mode
   logical               :: logwann, wvfn_formatted, write_unk, write_eig, &
   ! begin change Lopez, Thonhauser, Souza
                            write_amn,write_mmn,reduce_unk,write_spn,&
                            write_unkg,write_uhu,&
                            write_dmn,read_sym, & !YN
                            write_uIu, spn_formatted, uHu_formatted, uIu_formatted, & !ivo
   ! end change Lopez, Thonhauser, Souza
   ! shc
                            write_sHu, write_sIu, sHu_formatted, sIu_formatted, &
   ! end shc
   ! irreducible BZ
                            irr_bz, &
   ! vv: Begin SCDM keywords
                            scdm_proj
   character(LEN=15)     :: scdm_entanglement
   real(DP)              :: scdm_mu, scdm_sigma
   ! vv: End SCDM keywords
   ! run check for regular mesh
   logical               :: regular_mesh = .true.
   ! input data from nnkp file
   real(DP), allocatable :: center_w(:,:)     ! center_w(3,n_wannier)
   integer,  allocatable :: spin_eig(:)
   real(DP), allocatable :: spin_qaxis(:,:)
   integer, allocatable  :: l_w(:), mr_w(:) ! l and mr of wannier (n_wannier) as from table 3.1,3.2 of spec.
   integer, allocatable  :: r_w(:)      ! index of radial function (n_wannier) as from table 3.3 of spec.
   real(DP), allocatable :: xaxis(:,:),zaxis(:,:) ! xaxis and zaxis(3,n_wannier)
   real(DP), allocatable :: alpha_w(:)  ! alpha_w(n_wannier) ( called zona in wannier spec)
   !
   real(DP), allocatable :: csph(:,:)    ! expansion coefficients of gf on QE ylm function (16,n_wannier)
   CHARACTER(len=256) :: seedname  = 'wannier'  ! prepended to file names in wannier90
   ! For implementation of wannier_lib
   integer               :: mp_grid(3)            ! dimensions of MP k-point grid
   real(DP)              :: rlatt(3,3),glatt(3,3) ! real and recip lattices (Cartesian co-ords, units of Angstrom)
   real(DP), allocatable :: kpt_latt(:,:)  ! k-points in crystal co-ords. kpt_latt(3,iknum)
   real(DP), allocatable :: atcart(:,:)    ! atom centres in Cartesian co-ords and Angstrom units. atcart(3,nat)
   integer               :: num_bands      ! number of bands left after exclusions
   character(len=3), allocatable :: atsym(:) ! atomic symbols. atsym(nat)
   integer               :: num_nnmax=12
   complex(DP), allocatable :: m_mat(:,:,:,:), a_mat(:,:,:)
   complex(DP), allocatable :: u_mat(:,:,:), u_mat_opt(:,:,:)
   logical, allocatable     :: lwindow(:,:)
   real(DP), allocatable    :: wann_centers(:,:),wann_spreads(:)
   real(DP)                 :: spreads(3)
   real(DP), allocatable    :: eigval(:,:)
   logical                  :: old_spinor_proj  ! for compatability for nnkp files prior to W90v2.0
   integer,allocatable :: rir(:,:)
   logical,allocatable :: zerophase(:,:)
   real(DP), allocatable :: bvec(:,:), xbvec(:,:)    ! bvectors

   integer, PARAMETER :: header_len = 60
   !! The length of header in amn/mmn/eig/... files
   !! For unformatted stream IO, this must be the same as wannier90 when reading those files.
end module wannier
!

module atproj
   ! module for atomic projectors
   USE kinds, ONLY: DP

   ! Atomic projectors for species
   TYPE atproj_type
      CHARACTER(len=3) :: atsym ! atomic symbol
      INTEGER :: ngrid ! number of grid points
      REAL(DP), ALLOCATABLE :: xgrid(:)
      REAL(DP), ALLOCATABLE :: rgrid(:) ! exp(xgrid(:))
      INTEGER :: nproj ! total number of projectors for this species
      INTEGER, ALLOCATABLE :: l(:) ! angular momentum of each wfc
      REAL(DP), ALLOCATABLE :: radial(:, :) ! magnitude at each point, ngrid x nproj
   END TYPE atproj_type

   ! atomic proj input variables, start with atom_proj*
   LOGICAL :: atom_proj
   CHARACTER(LEN=256) :: atom_proj_dir ! directory of external projectors
   LOGICAL :: atom_proj_ext ! switch for using external files instead of orbitals from UPF
   INTEGER, PARAMETER :: nexatproj_max = 2000 ! max allowed number of projectors to be excluded
   INTEGER :: atom_proj_exclude(nexatproj_max) ! index starts from 1
   LOGICAL :: atom_proj_ortho ! whether perform Lowdin orthonormalization
   LOGICAL :: atom_proj_sym ! whether perform symmetrization

   ! atomic proj internal variables, using *atproj*
   INTEGER :: nexatproj ! actual number of excluded projectors
   INTEGER :: natproj ! total number of projectors = n_proj + nexatproj
   LOGICAL, ALLOCATABLE :: atproj_excl(:) ! size = total num of projectors
   INTEGER :: iun_atproj
   TYPE(atproj_type), ALLOCATABLE :: atproj_typs(:) ! all atom proj types

   REAL(DP), ALLOCATABLE :: tab_at(:, :, :)
   !! interpolation table for atomic projectors

CONTAINS

   SUBROUTINE skip_comments(file_unit)
      ! read a file_unit and skip lines starting with #
      !
      USE, INTRINSIC :: ISO_FORTRAN_ENV
      !
      IMPLICIT NONE
      !
      INTEGER, INTENT(in) :: file_unit
      CHARACTER(len=256) :: line
      INTEGER :: ret_code
      !
      DO
      READ (file_unit, '(A)', iostat=ret_code) line
      IF (ret_code == IOSTAT_END) EXIT
      IF (ret_code /= 0) THEN
         ! read error
         EXIT
      END IF
      IF (INDEX(ADJUSTL(line), "#") == 1) CYCLE
      EXIT
      END DO

      BACKSPACE file_unit

      RETURN
   END SUBROUTINE skip_comments

   !-----------------------------------------------------------------------
   SUBROUTINE write_file_amn(proj)
      !-----------------------------------------------------------------------
      ! On input proj has dimension num_bands x num_projs x num_kpoints
      !
      USE kinds, ONLY: DP
      USE io_global, ONLY: stdout, ionode
      USE wannier, ONLY: seedname, iun_amn, header_len

      IMPLICIT NONE

      COMPLEX(DP), INTENT(IN) :: proj(:, :, :)
      !
      INTEGER, EXTERNAL :: find_free_unit
      !
      INTEGER :: nbnd, nprj, nkpt
      INTEGER :: ib, ip, ik
      CHARACTER(len=9) :: cdate, ctime
      CHARACTER(len=header_len) :: header

      IF (ionode) THEN
         nbnd = SIZE(proj, 1)
         nprj = SIZE(proj, 2)
         nkpt = SIZE(proj, 3)

         iun_amn = find_free_unit()
         OPEN (unit=iun_amn, file=TRIM(seedname)//".amn", form='formatted')
         CALL date_and_tim(cdate, ctime)
         header = 'Created on '//cdate//' at '//ctime
         WRITE (iun_amn, *) header
         WRITE (iun_amn, *) nbnd, nkpt, nprj

         DO ik = 1, nkpt
            DO ip = 1, nprj
               DO ib = 1, nbnd
                  WRITE (iun_amn, '(3i5,2f18.12)') ib, ip, ik, proj(ib, ip, ik)
               END DO
            END DO
         END DO

         CLOSE (iun_amn)
      END IF

      RETURN
   END SUBROUTINE write_file_amn

   SUBROUTINE allocate_atproj_type(typ, ngrid, nproj)
      !
      IMPLICIT NONE
      !
      TYPE(atproj_type), INTENT(INOUT) :: typ
      INTEGER, INTENT(IN) :: ngrid, nproj
      INTEGER :: ierr
      !
      typ%ngrid = ngrid
      typ%nproj = nproj
      ALLOCATE (typ%xgrid(ngrid), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating typ%xgrid', 1)
      ALLOCATE (typ%rgrid(ngrid), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating typ%rgrid', 1)
      ALLOCATE (typ%l(nproj), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating typ%l', 1)
      ALLOCATE (typ%radial(ngrid, nproj), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating typ%radial', 1)

      RETURN
   END SUBROUTINE allocate_atproj_type

   SUBROUTINE read_atomproj(typs)
      !
      ! read data files for atom proj
      ! should be called only by one node
      !
      USE kinds, ONLY: dp
      USE io_global, ONLY: stdout
      USE ions_base, ONLY: nsp, atm
      !
      IMPLICIT NONE
      !
      TYPE(atproj_type), INTENT(INOUT) :: typs(nsp)
      !
      INTEGER, EXTERNAL :: find_free_unit
      !
      INTEGER :: i, j, it
      LOGICAL :: file_exists
      CHARACTER(len=256) :: filename
      INTEGER :: ngrid, nproj

      iun_atproj = find_free_unit()

      DO it = 1, nsp
         filename = TRIM(atom_proj_dir)//'/'//TRIM(atm(it))//".dat"
         INQUIRE (FILE=TRIM(filename), EXIST=file_exists)
         IF (.NOT. file_exists) &
            CALL errore('pw2wannier90', 'file not exists: '//TRIM(filename), 1)
         OPEN (unit=iun_atproj, file=TRIM(filename), form='formatted')
         CALL skip_comments(iun_atproj)

         READ (iun_atproj, *) ngrid, nproj
         WRITE (stdout, *) " Read from "//TRIM(filename)
         WRITE (stdout, '((A),(I4))') "   number of grid points   = ", ngrid
         WRITE (stdout, '((A),(I4))') "   number of projectors    = ", nproj

         CALL allocate_atproj_type(typs(it), ngrid, nproj)
         typs(it)%atsym = atm(it)

         READ (iun_atproj, *) (typs(it)%l(i), i=1, nproj)
         WRITE (stdout, '((A))', advance='no') "   ang. mom. of projectors = "
         DO i = 1, nproj
            WRITE (stdout, '(I4)', advance='no') typs(it)%l(i)
         END DO
         WRITE (stdout, *)
         WRITE (stdout, *)

         DO i = 1, ngrid
            READ (iun_atproj, *) typs(it)%xgrid(i), typs(it)%rgrid(i), &
            (typs(it)%radial(i, j), j=1, nproj)
            ! PRINT *, i, typs(it)%xgrid(i), typs(it)%rgrid(i)
         END DO

         CLOSE (iun_atproj)
      END DO

      RETURN
   END SUBROUTINE read_atomproj

   !-----------------------------------------------------------------------
   SUBROUTINE atomproj_wfc(ik, wfcatom)
      !-----------------------------------------------------------------------
      !! This routine computes the superposition of atomic wavefunctions
      !! for k-point "ik" - output in "wfcatom".
      !
      !  adapted from PW/src/atomic_wfc.f90, PP/src/atomic_wfc_nc_proj.f90
      !  to use external atomic wavefunctions other than UPF ones.
      !
      USE kinds, ONLY: DP
      USE constants, ONLY: tpi, fpi, pi
      USE cell_base, ONLY: omega, tpiba
      USE ions_base, ONLY: nat, ntyp => nsp, ityp, tau
      USE gvect, ONLY: mill, eigts1, eigts2, eigts3, g
      USE klist, ONLY: xk, igk_k, ngk
      USE wvfct, ONLY: npwx
      USE noncollin_module, ONLY: noncolin, npol, angle1, angle2, lspinorb, &
                                  domag, starting_spin_angle
      USE upf_spinorb,ONLY : rot_ylm, lmaxx, fcoef, lmaxx
      USE wannier, ONLY: n_proj
      !
      IMPLICIT NONE
      INTEGER, INTENT(IN) :: ik
      !! k-point index
      COMPLEX(DP), INTENT(OUT) :: wfcatom(npwx, npol, natproj)
      !! Superposition of atomic wavefunctions
      !
      ! ... local variables
      !
      INTEGER :: n_starting_wfc, lmax_wfc, nt, l, nb, na, m, lm, ig, iig, &
                 i0, i1, i2, i3, npw
      REAL(DP), ALLOCATABLE :: qg(:), ylm(:, :), chiq(:, :, :), gk(:, :)
      COMPLEX(DP), ALLOCATABLE :: sk(:), aux(:)
      COMPLEX(DP) :: kphase, lphase
      REAL(DP)    :: arg
      INTEGER :: nwfcm
      !! max number of radial atomic projectors across atoms
      INTEGER :: ierr

      CALL start_clock('atomproj_wfc')

      ! calculate max angular momentum required in wavefunctions
      lmax_wfc = 0
      nwfcm = 0
      DO nt = 1, ntyp
         lmax_wfc = MAX(lmax_wfc, MAXVAL(atproj_typs(nt)%l))
         nwfcm = MAX(nwfcm, atproj_typs(nt)%nproj)
      END DO
      !
      npw = ngk(ik)
      !
      ALLOCATE (ylm(npw, (lmax_wfc + 1)**2), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating ylm', 1)
      ALLOCATE (chiq(npw, nwfcm, ntyp), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating chiq', 1)
      ALLOCATE (gk(3, npw), qg(npw), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating gk/qg', 1)
      !
      DO ig = 1, npw
         iig = igk_k(ig, ik)
         gk(1, ig) = xk(1, ik) + g(1, iig)
         gk(2, ig) = xk(2, ik) + g(2, iig)
         gk(3, ig) = xk(3, ik) + g(3, iig)
         qg(ig) = gk(1, ig)**2 + gk(2, ig)**2 + gk(3, ig)**2
      END DO
      !
      !  ylm = spherical harmonics
      !
      CALL ylmr2((lmax_wfc + 1)**2, npw, gk, qg, ylm)
      !
      ! set now q=|k+G| in atomic units
      !
      DO ig = 1, npw
         qg(ig) = SQRT(qg(ig))*tpiba
      END DO
      !
      CALL interp_atproj(npw, qg, nwfcm, chiq)
      !
      DEALLOCATE (qg, gk)
      ALLOCATE (aux(npw), sk(npw), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating aux/sk', 1)
      !
      wfcatom(:, :, :) = (0.0_DP, 0.0_DP)
      n_starting_wfc = 0
      !
      DO na = 1, nat
        arg = (xk(1, ik)*tau(1, na) + xk(2, ik)*tau(2, na) + xk(3, ik)*tau(3, na))*tpi
        kphase = CMPLX(COS(arg), -SIN(arg), KIND=DP)
        !
        !     sk is the structure factor
        !
        DO ig = 1, npw
          iig = igk_k(ig, ik)
          sk(ig) = kphase*eigts1(mill(1, iig), na)* &
                   eigts2(mill(2, iig), na)* &
                   eigts3(mill(3, iig), na)
        END DO
        !
        nt = ityp(na)
        DO nb = 1, atproj_typs(nt)%nproj
          l = atproj_typs(nt)%l(nb)
          lphase = (0.D0, 1.D0)**l
          !
          !  only support without spin-orbit coupling
          !  if needed in the future, add code according to
          !  PP/src/atomic_wfc_nc_proj.f90
          !
          CALL atomic_wfc___()
          !
          ! END IF
          !
        END DO
        !
      END DO

      DEALLOCATE (aux, sk, chiq, ylm)

      CALL stop_clock('atomproj_wfc')

      RETURN

   CONTAINS

      SUBROUTINE atomic_wfc___()
        !
        ! ... LSDA or nonmagnetic case
        !
        DO m = 1, 2*l + 1
          lm = l**2 + m
          n_starting_wfc = n_starting_wfc + 1
          IF (n_starting_wfc > natproj) CALL errore &
            ('atomic_wfc___', 'internal error: too many wfcs', 1)
          !
          DO ig = 1, npw
            wfcatom(ig, 1, n_starting_wfc) = lphase* &
                                             sk(ig)*ylm(ig, lm)*chiq(ig, nb, nt)
          END DO
          !
        END DO
        !
      END SUBROUTINE atomic_wfc___
      !
   END SUBROUTINE atomproj_wfc

   SUBROUTINE interp_atproj(npw, qg, nwfcm, chiq)
      !-----------------------------------------------------------------------
      !
      ! computes chiq: radial fourier transform of atomic projector chi
      !
      !! adapted from upflib/interp_atwfc.f90
      !  to support external projectors
      !
      USE kinds, ONLY: dp
      USE ions_base, ONLY: nsp
      USE uspp_data, ONLY: dq
      !
      IMPLICIT NONE
      !
      INTEGER, INTENT(IN)  :: npw
      INTEGER, INTENT(IN)  :: nwfcm
      REAL(dp), INTENT(IN) :: qg(npw)
      REAL(dp), INTENT(OUT):: chiq(npw, nwfcm, nsp)
      !
      INTEGER :: nt, nb, ig
      INTEGER :: i0, i1, i2, i3
      REAL(dp):: qgr, px, ux, vx, wx
      !
      DO nt = 1, nsp
        DO nb = 1, atproj_typs(nt)%nproj
          DO ig = 1, npw
            qgr = qg(ig)
            px = qgr/dq - INT(qgr/dq)
            ux = 1.D0 - px
            vx = 2.D0 - px
            wx = 3.D0 - px
            i0 = INT(qgr/dq) + 1
            i1 = i0 + 1
            i2 = i0 + 2
            i3 = i0 + 3
            chiq(ig, nb, nt) = &
              tab_at(i0, nb, nt)*ux*vx*wx/6.D0 + &
              tab_at(i1, nb, nt)*px*vx*wx/2.D0 - &
              tab_at(i2, nb, nt)*px*ux*wx/2.D0 + &
              tab_at(i3, nb, nt)*px*ux*vx/6.D0
          END DO
        END DO
      END DO
  
   END SUBROUTINE interp_atproj
  
   SUBROUTINE init_tab_atproj(intra_bgrp_comm)
      !-----------------------------------------------------------------------
      !! This routine computes a table with the radial Fourier transform
      !! of the atomic wavefunctions.
      !!
      !! adapted from upflib/init_tab_atwfc.f90
      !! to support external projectors
      !
      USE kinds, ONLY: DP
      USE upf_const, ONLY: fpi
      USE uspp_data, ONLY: nqx, dq
      USE ions_base, ONLY: nsp
      USE cell_base, ONLY: omega
      USE mp, ONLY: mp_sum
      !
      IMPLICIT NONE
      !
      INTEGER, INTENT(IN) :: intra_bgrp_comm
      !
      INTEGER :: nt, nb, iq, ir, l, startq, lastq, ndm, nwfcm
      !
      REAL(DP), ALLOCATABLE :: aux(:), vchi(:), rab(:)
      REAL(DP) :: vqint, pref, q
      !
      ndm = 0
      nwfcm = 0
      DO nt = 1, nsp
        ndm = MAX(ndm, atproj_typs(nt)%ngrid)
        nwfcm = MAX(nwfcm, atproj_typs(nt)%nproj)
      END DO
      ALLOCATE (aux(ndm), vchi(ndm), rab(ndm))
      !
      ! chiq = radial fourier transform of atomic orbitals chi
      !
      pref = fpi/SQRT(omega)
      ! needed to normalize atomic wfcs (not a bad idea in general)
      CALL divide(intra_bgrp_comm, nqx, startq, lastq)
      !
      ! nqx = INT( (SQRT(ecutwfc) / dq + 4) )
      ALLOCATE (tab_at(nqx, nwfcm, nsp))
      tab_at(:, :, :) = 0.0_DP
      !
      DO nt = 1, nsp
        rab = (atproj_typs(nt)%xgrid(2) - atproj_typs(nt)%xgrid(1))* &
              atproj_typs(nt)%rgrid
        DO nb = 1, atproj_typs(nt)%nproj
          !
          l = atproj_typs(nt)%l(nb)
          !
          DO iq = startq, lastq
            q = dq*(iq - 1)
            CALL sph_bes(atproj_typs(nt)%ngrid, atproj_typs(nt)%rgrid, q, l, aux)
            DO ir = 1, atproj_typs(nt)%ngrid
              vchi(ir) = atproj_typs(nt)%radial(ir, nb)*aux(ir)*atproj_typs(nt)%rgrid(ir)
            END DO
            CALL simpson(atproj_typs(nt)%ngrid, vchi, rab, vqint)
            tab_at(iq, nb, nt) = vqint*pref
          END DO
          !
        END DO
      END DO
      !
      CALL mp_sum(tab_at, intra_bgrp_comm)
      !
      DEALLOCATE (aux, vchi, rab)
      !
      RETURN
      !
   END SUBROUTINE init_tab_atproj

   SUBROUTINE deallocate_atproj
      IMPLICIT NONE

      IF (ALLOCATED(tab_at)) DEALLOCATE (tab_at)

      RETURN
   END SUBROUTINE deallocate_atproj

end module atproj
!
!------------------------------------------------------------------------
PROGRAM pw2wannier90
  ! This is the interface to the Wannier90 code: see http://www.wannier.org
  !------------------------------------------------------------------------
  !
  USE io_global,  ONLY : stdout, ionode, ionode_id
  USE mp_global,  ONLY : mp_startup
  USE mp_pools,   ONLY : npool
  USE mp_bands,   ONLY : nbgrp
  USE mp,         ONLY : mp_bcast
  USE mp_world,   ONLY : world_comm
  USE cell_base,  ONLY : at, bg
  USE lsda_mod,   ONLY : nspin, isk
  USE klist,      ONLY : nkstot
  USE io_files,   ONLY : prefix, tmp_dir
  USE noncollin_module, ONLY : noncolin
  USE control_flags,    ONLY : gamma_only
  USE environment,ONLY : environment_start, environment_end
  USE wannier
  use atproj, only : atom_proj, atom_proj_dir, atom_proj_ext, &
                     atom_proj_exclude, atom_proj_ortho, atom_proj_sym
  USE read_namelists_module, only : check_namelist_read
  !
  IMPLICIT NONE
  !
  CHARACTER(LEN=256), EXTERNAL :: trimcheck
  !
  INTEGER :: ios
  CHARACTER(len=4) :: spin_component
  CHARACTER(len=256) :: outdir

  ! these are in wannier module.....-> integer :: ispinw, ikstart, ikstop, iknum
  NAMELIST / inputpp / outdir, prefix, spin_component, wan_mode, &
       seedname, write_unk, write_amn, write_mmn, write_spn, write_eig,&
   ! begin change Lopez, Thonhauser, Souza
       wvfn_formatted, reduce_unk, write_unkg, write_uhu,&
       write_dmn, read_sym, & !YN:
       write_uIu, spn_formatted, uHu_formatted, uIu_formatted,& !ivo
   ! end change Lopez, Thonhauser, Souza
   ! shc
       write_sHu, write_sIu, sHu_formatted, sIu_formatted,&
   ! end shc
       regular_mesh,& !gresch
       irr_bz,& ! Koretsune
   ! begin change Vitale
       scdm_proj, scdm_entanglement, scdm_mu, scdm_sigma, &
   ! end change Vitale
       atom_proj, atom_proj_dir, atom_proj_ext, atom_proj_exclude, &
       atom_proj_ortho
  !
  ! initialise environment
  !
#if defined(__MPI)
  CALL mp_startup ( )
#endif
  !! not sure if this should be called also in 'library' mode or not !!
  CALL environment_start ( 'PW2WANNIER' )
  !
  CALL start_clock( 'init_pw2wan' )
  !
  ! Read input on i/o node and broadcast to the rest
  !
  ios = 0
  IF(ionode) THEN
     !
     ! Check to see if we are reading from a file
     !
     CALL input_from_file()
     !
     !   set default values for variables in namelist
     !
     CALL get_environment_variable( 'ESPRESSO_TMPDIR', outdir )
     IF ( trim( outdir ) == ' ' ) outdir = './'
     prefix = ' '
     seedname = 'wannier'
     spin_component = 'none'
     wan_mode = 'standalone'
     wvfn_formatted = .false.
     spn_formatted=.false.
     uHu_formatted=.false.
     uIu_formatted=.false.
     write_unk = .false.
     write_amn = .true.
     write_mmn = .true.
     write_spn = .false.
     write_eig = .true.
     ! begin change Lopez, Thonhauser, Souza
     write_uhu = .false.
     write_uIu = .false. !ivo
     ! end change Lopez, Thonhauser, Souza
     ! shc
     write_sHu = .false.
     write_sIu = .false.
     sHu_formatted=.false.
     sIu_formatted=.false.
     ! end shc
     reduce_unk= .false.
     write_unkg= .false.
     write_dmn = .false. !YN:
     read_sym  = .false. !YN:
     irr_bz = .false.
     scdm_proj = .false.
     scdm_entanglement = 'isolated'
     scdm_mu = 0.0_dp
     scdm_sigma = 1.0_dp
     atom_proj = .false.
     atom_proj_dir = './'
     atom_proj_ext = .false.
     atom_proj_ortho = .true.
     atom_proj_exclude = -1
     ! Haven't tested symmetrization with external projectors, disable it for now
     atom_proj_sym = .false.
     !
     !     reading the namelist inputpp
     !
     READ (5, inputpp, iostat=ios)
     !
     !     Check of namelist variables
     !
     tmp_dir = trimcheck(outdir)
     ! back to all nodes
  ENDIF
  !
  CALL mp_bcast(ios,ionode_id, world_comm)
  CALL check_namelist_read(ios, 5, "inputpp")
  !
  ! broadcast input variable to all nodes
  !
  CALL mp_bcast(outdir,ionode_id, world_comm)
  CALL mp_bcast(tmp_dir,ionode_id, world_comm)
  CALL mp_bcast(prefix,ionode_id, world_comm)
  CALL mp_bcast(seedname,ionode_id, world_comm)
  CALL mp_bcast(spin_component,ionode_id, world_comm)
  CALL mp_bcast(wan_mode,ionode_id, world_comm)
  CALL mp_bcast(wvfn_formatted,ionode_id, world_comm)
  CALL mp_bcast(write_unk,ionode_id, world_comm)
  CALL mp_bcast(write_amn,ionode_id, world_comm)
  CALL mp_bcast(write_mmn,ionode_id, world_comm)
  CALL mp_bcast(write_eig,ionode_id, world_comm)
  ! begin change Lopez, Thonhauser, Souza
  CALL mp_bcast(write_uhu,ionode_id, world_comm)
  CALL mp_bcast(write_uIu,ionode_id, world_comm) !ivo
  ! end change Lopez, Thonhauser, Souza
  ! shc
  CALL mp_bcast(write_sHu,ionode_id, world_comm)
  CALL mp_bcast(write_sIu,ionode_id, world_comm)
  ! end shc
  CALL mp_bcast(write_spn,ionode_id, world_comm)
  CALL mp_bcast(reduce_unk,ionode_id, world_comm)
  CALL mp_bcast(write_unkg,ionode_id, world_comm)
  CALL mp_bcast(write_dmn,ionode_id, world_comm)
  CALL mp_bcast(read_sym,ionode_id, world_comm)
  CALL mp_bcast(irr_bz,ionode_id, world_comm)
  CALL mp_bcast(scdm_proj,ionode_id, world_comm)
  CALL mp_bcast(scdm_entanglement,ionode_id, world_comm)
  CALL mp_bcast(scdm_mu,ionode_id, world_comm)
  CALL mp_bcast(scdm_sigma,ionode_id, world_comm)
  CALL mp_bcast(atom_proj, ionode_id, world_comm)
  CALL mp_bcast(atom_proj_dir, ionode_id, world_comm)
  CALL mp_bcast(atom_proj_ext,ionode_id, world_comm)
  CALL mp_bcast(atom_proj_ortho, ionode_id, world_comm)
  CALL mp_bcast(atom_proj_sym, ionode_id, world_comm)
  CALL mp_bcast(atom_proj_exclude, ionode_id, world_comm)
  !
  ! Check: kpoint distribution with pools not implemented
  !
  IF (npool > 1) CALL errore('pw2wannier90', 'pools not implemented', npool)
  !
  ! Check: bands distribution not implemented
  IF (nbgrp > 1) CALL errore('pw2wannier90', 'bands (-nb) not implemented', nbgrp)
  !
  !   Now allocate space for pwscf variables, read and check them.
  !
  logwann = .true.
  WRITE(stdout,*)
  WRITE(stdout,'(5x,A)') 'Reading nscf_save data'
  CALL read_file
  WRITE(stdout,*)
  !
  IF (noncolin.and.gamma_only) CALL errore('pw2wannier90',&
       'Non-collinear and gamma_only not implemented',1)
  IF (gamma_only.and.scdm_proj) CALL errore('pw2wannier90',&
       'Gamma_only and SCDM not implemented',1)
  IF (scdm_proj) then
    IF ((trim(scdm_entanglement) /= 'isolated') .AND. &
        (trim(scdm_entanglement) /= 'erfc') .AND. &
        (trim(scdm_entanglement) /= 'gaussian')) then
        call errore('pw2wannier90', &
             'Can not recognize the choice for scdm_entanglement. ' &
                    //'Valid options are: isolated, erfc and gaussian')
    ENDIF
  ENDIF
  IF (scdm_sigma <= 0._dp) &
    call errore('pw2wannier90','Sigma in the SCDM method must be positive.')
  IF (irr_bz) THEN
     IF (gamma_only) CALL errore('pw2wannier90', "irr_bz and gamma_only are not compatible", 1)
     IF (write_spn) CALL errore('pw2wannier90', "irr_bz and write_spn not implemented", 1)
     IF (write_unk) CALL errore('pw2wannier90', "irr_bz and write_unk not implemented", 1)
     IF (write_uHu) CALL errore('pw2wannier90', "irr_bz and write_uHu not implemented", 1)
     IF (write_uIu) CALL errore('pw2wannier90', "irr_bz and write_uIu not implemented", 1)
     IF (write_sHu) CALL errore('pw2wannier90', "irr_bz and write_sHu not implemented", 1)
     IF (write_sIu) CALL errore('pw2wannier90', "irr_bz and write_sIu not implemented", 1)
     IF (write_dmn) CALL errore('pw2wannier90', "irr_bz and write_dmn not implemented", 1)
     IF (scdm_proj) CALL errore('pw2wannier90', "irr_bz and SCDM not implemented", 1)
     IF (write_unkg) CALL errore('pw2wannier90', "irr_bz and write_unkg not implemented", 1)
  ENDIF
  IF (atom_proj) then
    IF (atom_proj_ext .and. noncolin) CALL errore('pw2wannier90', &
         "atom_proj_ext and noncolin not implemented", 1)
  ENDIF
  !
  SELECT CASE ( trim( spin_component ) )
  CASE ( 'up' )
     WRITE(stdout,*) ' Spin CASE ( up )'
     ispinw  = 1
     ikstart = 1
     ikstop  = nkstot/2
     iknum   = nkstot/2
  CASE ( 'down' )
     WRITE(stdout,*) ' Spin CASE ( down )'
     ispinw = 2
     ikstart = nkstot/2 + 1
     ikstop  = nkstot
     iknum   = nkstot/2
  CASE DEFAULT
     IF(noncolin) THEN
        WRITE(stdout,*) ' Spin CASE ( non-collinear )'
     ELSE
        WRITE(stdout,*) ' Spin CASE ( default = unpolarized )'
     ENDIF
     ispinw = 0
     ikstart = 1
     ikstop  = nkstot
     iknum   = nkstot
  END SELECT
  !
  CALL stop_clock( 'init_pw2wan' )
  !
  WRITE(stdout,*)
  WRITE(stdout,*) ' Wannier mode is: ',wan_mode
  WRITE(stdout,*)
  !
  IF(wan_mode=='standalone') THEN
     !
     WRITE(stdout,*) ' -----------------'
     WRITE(stdout,*) ' *** Reading nnkp '
     WRITE(stdout,*) ' -----------------'
     WRITE(stdout,*)
     CALL read_nnkp
     WRITE(stdout,*) ' Opening pp-files '
     CALL openfil_pp
     CALL ylm_expansion
     WRITE(stdout,*)
     WRITE(stdout,*)
     if(write_dmn)then
        WRITE(stdout,*) ' ----------------'
        WRITE(stdout,*) ' *** Compute DMN '
        WRITE(stdout,*) ' ----------------'
        WRITE(stdout,*)
        CALL compute_dmn !YN:
        WRITE(stdout,*)
     end if
     IF(write_amn) THEN
        IF(scdm_proj) THEN
           WRITE(stdout,*) ' --------------------------'
           WRITE(stdout,*) ' *** Compute  A with SCDM-k'
           WRITE(stdout,*) ' --------------------------'
           WRITE(stdout,*)
           if (noncolin) then
             CALL compute_amn_with_scdm_spinor
           else
             CALL compute_amn_with_scdm
           end if
        else if (atom_proj) then
          WRITE(stdout,*) ' -------------------------------------'
          WRITE(stdout,*) ' *** Compute  A with atomic projectors'
          WRITE(stdout,*) ' -------------------------------------'
          WRITE(stdout,*)
          CALL compute_amn_with_atomproj
        ELSE
           WRITE(stdout,*) ' --------------------------'
           WRITE(stdout,*) ' *** Compute  A projections'
           WRITE(stdout,*) ' --------------------------'
           WRITE(stdout,*)
           CALL compute_amn
        ENDIF
        WRITE(stdout,*)
     ELSE
        WRITE(stdout,*) ' -----------------------------'
        WRITE(stdout,*) ' *** A matrix is not computed '
        WRITE(stdout,*) ' -----------------------------'
        WRITE(stdout,*)
     ENDIF
     IF(write_mmn) THEN
        WRITE(stdout,*) ' ---------------'
        WRITE(stdout,*) ' *** Compute  M '
        WRITE(stdout,*) ' ---------------'
        WRITE(stdout,*)
        IF(irr_bz) THEN
           CALL compute_mmn_ibz
        ELSE
           CALL compute_mmn
        ENDIF
        WRITE(stdout,*)
     ELSE
        WRITE(stdout,*) ' -----------------------------'
        WRITE(stdout,*) ' *** M matrix is not computed '
        WRITE(stdout,*) ' -----------------------------'
        WRITE(stdout,*)
     ENDIF
     if(noncolin) then
        IF(write_spn) THEN
           WRITE(stdout,*) ' ------------------'
           WRITE(stdout,*) ' *** Compute  Spin '
           WRITE(stdout,*) ' ------------------'
           WRITE(stdout,*)
           CALL compute_spin
           WRITE(stdout,*)
        ELSE
           WRITE(stdout,*) ' --------------------------------'
           WRITE(stdout,*) ' *** Spin matrix is not computed '
           WRITE(stdout,*) ' --------------------------------'
           WRITE(stdout,*)
        ENDIF
     elseif(write_spn) then
        write(stdout,*) ' -----------------------------------'
        write(stdout,*) ' *** Non-collinear calculation is   '
        write(stdout,*) '     required for spin              '
        write(stdout,*) '     term  to be computed           '
        write(stdout,*) ' -----------------------------------'
     endif
     IF(write_uHu.or.write_uIu) THEN
        WRITE(stdout,*) ' ----------------'
        WRITE(stdout,*) ' *** Compute Orb '
        WRITE(stdout,*) ' ----------------'
        WRITE(stdout,*)
        CALL compute_orb
        WRITE(stdout,*)
     ELSE
        WRITE(stdout,*) ' -----------------------------------'
        WRITE(stdout,*) ' *** Orbital terms are not computed '
        WRITE(stdout,*) ' -----------------------------------'
        WRITE(stdout,*)
     ENDIF
     IF(write_sHu.or.write_sIu) THEN
        WRITE(stdout,*) ' ----------------'
        WRITE(stdout,*) ' *** Compute shc '
        WRITE(stdout,*) ' ----------------'
        WRITE(stdout,*)
        CALL compute_shc
        WRITE(stdout,*)
     ELSE
        WRITE(stdout,*) ' -----------------------------------'
        WRITE(stdout,*) ' *** SHC terms are not computed '
        WRITE(stdout,*) ' -----------------------------------'
        WRITE(stdout,*)
     ENDIF
     IF(write_eig) THEN
        WRITE(stdout,*) ' ----------------'
        WRITE(stdout,*) ' *** Write bands '
        WRITE(stdout,*) ' ----------------'
        WRITE(stdout,*)
     CALL write_band
        WRITE(stdout,*)
     ELSE
        WRITE(stdout,*) ' --------------------------'
        WRITE(stdout,*) ' *** Bands are not written '
        WRITE(stdout,*) ' --------------------------'
        WRITE(stdout,*)
     ENDIF
     IF(write_unk) THEN
        WRITE(stdout,*) ' --------------------'
        WRITE(stdout,*) ' *** Write plot info '
        WRITE(stdout,*) ' --------------------'
        WRITE(stdout,*)
        CALL write_plot
        WRITE(stdout,*)
     ELSE
        WRITE(stdout,*) ' -----------------------------'
        WRITE(stdout,*) ' *** Plot info is not printed '
        WRITE(stdout,*) ' -----------------------------'
        WRITE(stdout,*)
     ENDIF
     IF(write_unkg) THEN
        WRITE(stdout,*) ' --------------------'
        WRITE(stdout,*) ' *** Write parity info '
        WRITE(stdout,*) ' --------------------'
        WRITE(stdout,*)
        CALL write_parity
        WRITE(stdout,*)
     ELSE
        WRITE(stdout,*) ' -----------------------------'
        WRITE(stdout,*) ' *** Parity info is not printed '
        WRITE(stdout,*) ' -----------------------------'
        WRITE(stdout,*)
     ENDIF
     WRITE(stdout,*) ' ------------'
     WRITE(stdout,*) ' *** Stop pp '
     WRITE(stdout,*) ' ------------'
     WRITE(stdout,*)
     !
     IF ( ionode ) WRITE( stdout, *  )
     CALL print_clock( 'init_pw2wan' )
     CALL print_clock( 'compute_dmn'  )!YN:
     CALL print_clock( 'compute_amn'  )
     CALL print_clock( 'compute_mmn'  )
     CALL print_clock( 'compute_immn'  )
     CALL print_clock( 'compute_shc'  )
     CALL print_clock( 'write_unk'    )
     CALL print_clock( 'write_parity' )
     ! not sure if this should be called also in 'library' mode or not !!
     CALL environment_end ( 'PW2WANNIER' )
     IF ( ionode ) WRITE( stdout, *  )
     CALL stop_pp
     !
  ENDIF
  !
  IF(wan_mode=='library') THEN
     !
!     seedname='wannier'
     WRITE(stdout,*) ' Setting up...'
     CALL setup_nnkp
     WRITE(stdout,*)
     WRITE(stdout,*) ' Opening pp-files '
     CALL openfil_pp
     WRITE(stdout,*)
     WRITE(stdout,*) ' Ylm expansion'
     CALL ylm_expansion
     WRITE(stdout,*)
     CALL compute_amn
     CALL compute_mmn
     if(noncolin) then
        IF(write_spn) THEN
           CALL compute_spin
        ENDIF
     ENDIF
     IF(write_uHu.or.write_uIu) THEN
        CALL compute_orb
     ENDIF
     CALL write_band
     IF(write_unk) CALL write_plot
     IF(write_unkg) THEN
        CALL write_parity
     ENDIF
     CALL run_wannier
     CALL lib_dealloc
     CALL stop_pp
     !
  ENDIF
  !
  IF(wan_mode=='wannier2sic') THEN
     !
     CALL read_nnkp
     CALL wan2sic
     !
  ENDIF
  !
  STOP
END PROGRAM pw2wannier90
!
!-----------------------------------------------------------------------
SUBROUTINE lib_dealloc
  !-----------------------------------------------------------------------
  !
  USE wannier

  IMPLICIT NONE

  DEALLOCATE(m_mat,u_mat,u_mat_opt,a_mat,eigval)

  RETURN
END SUBROUTINE lib_dealloc
!
!-----------------------------------------------------------------------
SUBROUTINE setup_nnkp
  !-----------------------------------------------------------------------
  !
  USE io_global, ONLY : stdout, ionode, ionode_id
  USE kinds,     ONLY : DP
  USE constants, ONLY : eps6, tpi, bohr => BOHR_RADIUS_ANGS
  USE cell_base, ONLY : at, bg, alat
  USE gvect,     ONLY : g, gg
  USE ions_base, ONLY : nat, tau, ityp, atm
  USE klist,     ONLY : xk
  USE mp,        ONLY : mp_bcast, mp_sum
  USE mp_pools,  ONLY : intra_pool_comm
  USE mp_world,  ONLY : world_comm
  USE wvfct,     ONLY : nbnd,npwx
  USE control_flags,    ONLY : gamma_only
  USE noncollin_module, ONLY : noncolin
  USE wannier

  IMPLICIT NONE
  real(DP) :: g_(3), gg_
  INTEGER  :: ik, ib, ig, iw, ia, indexb, TYPE
  INTEGER, ALLOCATABLE :: ig_check(:,:)
  real(DP) :: xnorm, znorm, coseno
  INTEGER  :: exclude_bands(nbnd)

  ! aam: translations between PW2Wannier90 and Wannier90
  ! pw2wannier90   <==>   Wannier90
  !    nbnd                num_bands_tot
  !    n_wannier           num_wann
  !    num_bands           num_bands
  !    nat                 num_atoms
  !    iknum               num_kpts
  !    rlatt               transpose(real_lattice)
  !    glatt               transpose(recip_lattice)
  !    kpt_latt            kpt_latt
  !    nnb                 nntot
  !    kpb                 nnlist
  !    g_kpb               nncell
  !    mp_grid             mp_grid
  !    center_w            proj_site
  !    l_w,mr_w,r_w        proj_l,proj_m,proj_radial
  !    xaxis,zaxis         proj_x,proj_z
  !    alpha_w             proj_zona
  !    exclude_bands       exclude_bands
  !    atcart              atoms_cart
  !    atsym               atom_symbols

  ALLOCATE( kpt_latt(3,iknum) )
  ALLOCATE( atcart(3,nat), atsym(nat) )
  ALLOCATE( kpb(iknum,num_nnmax), g_kpb(3,iknum,num_nnmax) )
  ALLOCATE( center_w(3,nbnd), alpha_w(nbnd), l_w(nbnd), &
       mr_w(nbnd), r_w(nbnd), zaxis(3,nbnd), xaxis(3,nbnd) )
  ALLOCATE( excluded_band(nbnd) )

  ! real lattice (Cartesians, Angstrom)
  rlatt(:,:) = transpose(at(:,:))*alat*bohr
  ! reciprocal lattice (Cartesians, Angstrom)
  glatt(:,:) = transpose(bg(:,:))*tpi/(alat*bohr)
  ! convert Cartesian k-points to crystallographic co-ordinates
  kpt_latt(:,1:iknum)=xk(:,1:iknum)
  CALL cryst_to_cart(iknum,kpt_latt,at,-1)
  ! atom co-ordinates in Cartesian co-ords and Angstrom units
  atcart(:,:) = tau(:,:)*bohr*alat
  ! atom symbols
  DO ia=1,nat
     TYPE=ityp(ia)
     atsym(ia)=atm(TYPE)
  ENDDO

  ! MP grid dimensions
  CALL find_mp_grid()

  WRITE(stdout,'("  - Number of atoms is (",i3,")")') nat

#if defined(__WANLIB)
  IF (ionode) THEN
     CALL wannier_setup(seedname,mp_grid,iknum,rlatt, &               ! input
          glatt,kpt_latt,nbnd,nat,atsym,atcart,gamma_only,noncolin, & ! input
          nnb,kpb,g_kpb,num_bands,n_wannier,center_w, &               ! output
          l_w,mr_w,r_w,zaxis,xaxis,alpha_w,exclude_bands)             ! output
  ENDIF
#endif

  CALL mp_bcast(nnb,ionode_id, world_comm)
  CALL mp_bcast(kpb,ionode_id, world_comm)
  CALL mp_bcast(g_kpb,ionode_id, world_comm)
  CALL mp_bcast(num_bands,ionode_id, world_comm)
  CALL mp_bcast(n_wannier,ionode_id, world_comm)
  CALL mp_bcast(center_w,ionode_id, world_comm)
  CALL mp_bcast(l_w,ionode_id, world_comm)
  CALL mp_bcast(mr_w,ionode_id, world_comm)
  CALL mp_bcast(r_w,ionode_id, world_comm)
  CALL mp_bcast(zaxis,ionode_id, world_comm)
  CALL mp_bcast(xaxis,ionode_id, world_comm)
  CALL mp_bcast(alpha_w,ionode_id, world_comm)
  CALL mp_bcast(exclude_bands,ionode_id, world_comm)

  IF(noncolin) THEN
     n_proj=n_wannier/2
  ELSE
     n_proj=n_wannier
  ENDIF

  ALLOCATE( gf(npwx,n_proj), csph(16,n_proj) )

  WRITE(stdout,'("  - Number of wannier functions is (",i3,")")') n_wannier

  excluded_band(1:nbnd)=.false.
  nexband=0
  band_loop: DO ib=1,nbnd
     indexb=exclude_bands(ib)
     IF (indexb>nbnd .or. indexb<0) THEN
        CALL errore('setup_nnkp',' wrong excluded band index ', 1)
     ELSEIF (indexb==0) THEN
        exit band_loop
     ELSE
        nexband=nexband+1
        excluded_band(indexb)=.true.
     ENDIF
  ENDDO band_loop

  IF ( (nbnd-nexband)/=num_bands ) &
       CALL errore('setup_nnkp',' something wrong with num_bands',1)

  DO iw=1,n_proj
     xnorm = sqrt(xaxis(1,iw)*xaxis(1,iw) + xaxis(2,iw)*xaxis(2,iw) + &
          xaxis(3,iw)*xaxis(3,iw))
     IF (xnorm < eps6) CALL errore ('setup_nnkp',' |xaxis| < eps ',1)
     znorm = sqrt(zaxis(1,iw)*zaxis(1,iw) + zaxis(2,iw)*zaxis(2,iw) + &
          zaxis(3,iw)*zaxis(3,iw))
     IF (znorm < eps6) CALL errore ('setup_nnkp',' |zaxis| < eps ',1)
     coseno = (xaxis(1,iw)*zaxis(1,iw) + xaxis(2,iw)*zaxis(2,iw) + &
          xaxis(3,iw)*zaxis(3,iw))/xnorm/znorm
     IF (abs(coseno) > eps6) &
          CALL errore('setup_nnkp',' xaxis and zaxis are not orthogonal !',1)
     IF (alpha_w(iw) < eps6) &
          CALL errore('setup_nnkp',' zona value must be positive', 1)
     ! convert wannier center in cartesian coordinates (in unit of alat)
     CALL cryst_to_cart( 1, center_w(:,iw), at, 1 )
  ENDDO
  WRITE(stdout,*) ' - All guiding functions are given '

  nnbx=0
  nnb=max(nnbx,nnb)

  ALLOCATE( ig_(iknum,nnb), ig_check(iknum,nnb) )
  ALLOCATE( zerophase(iknum,nnb) )
  zerophase = .false.

  DO ik=1, iknum
     DO ib = 1, nnb
        IF ( (g_kpb(1,ik,ib).eq.0) .and.  &
             (g_kpb(2,ik,ib).eq.0) .and.  &
             (g_kpb(3,ik,ib).eq.0) ) zerophase(ik,ib) = .true.
        g_(:) = REAL( g_kpb(:,ik,ib) )
        CALL cryst_to_cart (1, g_, bg, 1)
        gg_ = g_(1)*g_(1) + g_(2)*g_(2) + g_(3)*g_(3)
        ig_(ik,ib) = 0
        ig = 1
        DO WHILE  (gg(ig) <= gg_ + eps6)
           IF ( (abs(g(1,ig)-g_(1)) < eps6) .and.  &
                (abs(g(2,ig)-g_(2)) < eps6) .and.  &
                (abs(g(3,ig)-g_(3)) < eps6)  ) ig_(ik,ib) = ig
           ig= ig +1
        ENDDO
     ENDDO
  ENDDO

  ig_check(:,:) = ig_(:,:)
  CALL mp_sum( ig_check, intra_pool_comm )
  DO ik=1, iknum
     DO ib = 1, nnb
        IF (ig_check(ik,ib) ==0) &
          CALL errore('setup_nnkp', &
                      ' g_kpb vector is not in the list of Gs', 100*ik+ib )
     ENDDO
  ENDDO
  DEALLOCATE (ig_check)

  WRITE(stdout,*) ' - All neighbours are found '
  WRITE(stdout,*)

  RETURN
END SUBROUTINE setup_nnkp
 !
 !-----------------------------------------------------------------------
SUBROUTINE run_wannier
  !-----------------------------------------------------------------------
  !
  USE io_global, ONLY : ionode, ionode_id
  USE ions_base, ONLY : nat
  USE mp,        ONLY : mp_bcast
  USE mp_world,  ONLY : world_comm
  USE control_flags, ONLY : gamma_only
  USE wannier

  IMPLICIT NONE

  ALLOCATE(u_mat(n_wannier,n_wannier,iknum))
  ALLOCATE(u_mat_opt(num_bands,n_wannier,iknum))
  ALLOCATE(lwindow(num_bands,iknum))
  ALLOCATE(wann_centers(3,n_wannier))
  ALLOCATE(wann_spreads(n_wannier))

#if defined(__WANLIB)
  IF (ionode) THEN
     CALL wannier_run(seedname,mp_grid,iknum,rlatt, &                ! input
          glatt,kpt_latt,num_bands,n_wannier,nnb,nat, &              ! input
          atsym,atcart,gamma_only,m_mat,a_mat,eigval, &              ! input
          u_mat,u_mat_opt,lwindow,wann_centers,wann_spreads,spreads) ! output
  ENDIF
#endif

  CALL mp_bcast(u_mat,ionode_id, world_comm)
  CALL mp_bcast(u_mat_opt,ionode_id, world_comm)
  CALL mp_bcast(lwindow,ionode_id, world_comm)
  CALL mp_bcast(wann_centers,ionode_id, world_comm)
  CALL mp_bcast(wann_spreads,ionode_id, world_comm)
  CALL mp_bcast(spreads,ionode_id, world_comm)

  RETURN
END SUBROUTINE run_wannier
!-----------------------------------------------------------------------
!
SUBROUTINE find_mp_grid()
  !-----------------------------------------------------------------------
  !
  USE io_global, ONLY : stdout
  USE kinds,     ONLY: DP
  USE wannier

  IMPLICIT NONE

  ! <<<local variables>>>
  INTEGER  :: ik,ntemp,ii
  real(DP) :: min_k,temp(3,iknum),mpg1

  min_k=minval(kpt_latt(1,:))
  ii=0
  DO ik=1,iknum
     IF (kpt_latt(1,ik)==min_k) THEN
        ii=ii+1
        temp(:,ii)=kpt_latt(:,ik)
     ENDIF
  ENDDO
  ntemp=ii

  min_k=minval(temp(2,1:ntemp))
  ii=0
  DO ik=1,ntemp
     IF (temp(2,ik)==min_k) THEN
        ii=ii+1
     ENDIF
  ENDDO
  mp_grid(3)=ii

  min_k=minval(temp(3,1:ntemp))
  ii=0
  DO ik=1,ntemp
     IF (temp(3,ik)==min_k) THEN
        ii=ii+1
     ENDIF
  ENDDO
  mp_grid(2)=ii

  IF ( (mp_grid(2)==0) .or. (mp_grid(3)==0) ) &
       CALL errore('find_mp_grid',' one or more mp_grid dimensions is zero', 1)

  mpg1=iknum/(mp_grid(2)*mp_grid(3))

  mp_grid(1) = nint(mpg1)

  WRITE(stdout,*)
  WRITE(stdout,'(3(a,i3))') '  MP grid is ',mp_grid(1),' x',mp_grid(2),' x',mp_grid(3)

  IF (real(mp_grid(1),kind=DP)/=mpg1) &
       CALL errore('find_mp_grid',' determining mp_grid failed', 1)

  RETURN
END SUBROUTINE find_mp_grid
!-----------------------------------------------------------------------
!
SUBROUTINE read_nnkp
  !-----------------------------------------------------------------------
  !
  USE io_global, ONLY : stdout, ionode, ionode_id
  USE kinds,     ONLY: DP
  USE constants, ONLY : eps6, tpi, bohr => BOHR_RADIUS_ANGS
  USE cell_base, ONLY : at, bg, alat
  USE gvect,     ONLY : g, gg
  USE klist,     ONLY : nkstot, xk
  USE mp,        ONLY : mp_bcast, mp_sum
  USE mp_pools,  ONLY : intra_pool_comm
  USE mp_world,  ONLY : world_comm
  USE wvfct,     ONLY : npwx, nbnd
  USE noncollin_module, ONLY : noncolin
  USE wannier
  USE atproj,    ONLY : atom_proj

  IMPLICIT NONE
  !
  INTEGER, EXTERNAL :: find_free_unit
  !
  real(DP) :: g_(3), gg_
  INTEGER :: ik, ib, ig, ipol, iw, idum, indexb
  INTEGER numk, i, j
  INTEGER, ALLOCATABLE :: ig_check(:,:)
  real(DP) :: xx(3), xnorm, znorm, coseno
  LOGICAL :: have_nnkp,found
  INTEGER :: tmp_auto ! vv: Needed for the selection of projections with SCDM
  REAL(DP), ALLOCATABLE :: xkc_full(:,:)

  IF (ionode) THEN  ! Read nnkp file on ionode only

     INQUIRE(file=trim(seedname)//".nnkp",exist=have_nnkp)
     IF(.not. have_nnkp) THEN
        CALL errore( 'pw2wannier90', 'Could not find the file '&
           &//trim(seedname)//'.nnkp', 1 )
     ENDIF

     iun_nnkp = find_free_unit()
     OPEN (unit=iun_nnkp, file=trim(seedname)//".nnkp",form='formatted', status="old")

  ENDIF

  nnbx=0

  !   check the information from *.nnkp with the nscf_save data
  WRITE(stdout,*) ' Checking info from wannier.nnkp file'
  WRITE(stdout,*)

  IF (ionode) THEN   ! read from ionode only

     CALL scan_file_to('real_lattice',found)
     if(.not.found) then
        CALL errore( 'pw2wannier90', 'Could not find real_lattice block in '&
           &//trim(seedname)//'.nnkp', 1 )
     endif
     DO j=1,3
        READ(iun_nnkp,*) (rlatt(i,j),i=1,3)
        DO i = 1,3
           rlatt(i,j) = rlatt(i,j)/(alat*bohr)
        ENDDO
     ENDDO
     DO j=1,3
        DO i=1,3
           IF(abs(rlatt(i,j)-at(i,j))>eps6) THEN
              WRITE(stdout,*)  ' Something wrong! '
              WRITE(stdout,*)  ' rlatt(i,j) =',rlatt(i,j),  ' at(i,j)=',at(i,j)
              CALL errore( 'pw2wannier90', 'Direct lattice mismatch', 3*j+i )
           ENDIF
        ENDDO
     ENDDO
     WRITE(stdout,*) ' - Real lattice is ok'

     CALL scan_file_to('recip_lattice',found)
     if(.not.found) then
        CALL errore( 'pw2wannier90', 'Could not find recip_lattice block in '&
           &//trim(seedname)//'.nnkp', 1 )
     endif
     DO j=1,3
        READ(iun_nnkp,*) (glatt(i,j),i=1,3)
        DO i = 1,3
           glatt(i,j) = (alat*bohr)*glatt(i,j)/tpi
        ENDDO
     ENDDO
     DO j=1,3
        DO i=1,3
           IF(abs(glatt(i,j)-bg(i,j))>eps6) THEN
              WRITE(stdout,*)  ' Something wrong! '
              WRITE(stdout,*)  ' glatt(i,j)=',glatt(i,j), ' bg(i,j)=',bg(i,j)
              CALL errore( 'pw2wannier90', 'Reciprocal lattice mismatch', 3*j+i )
           ENDIF
        ENDDO
     ENDDO
     WRITE(stdout,*) ' - Reciprocal lattice is ok'

     CALL scan_file_to('kpoints',found)
     if(.not.found) then
        CALL errore( 'pw2wannier90', 'Could not find kpoints block in '&
           &//trim(seedname)//'.nnkp', 1 )
     endif
     READ(iun_nnkp,*) numk
     IF(irr_bz) THEN
        ALLOCATE(xkc_full(3,numk))
        DO i=1,numk
           READ(iun_nnkp,*) xkc_full(:,i)
        END DO
        !IF(any(abs(xkc_full(:,:)) > 0.5)) THEN
        !   CALL errore( 'pw2wannier90', 'kpoints should be -0.5 <= k < 0.5', 1 )
        !ENDIF
     ELSE
        IF(numk/=iknum) THEN
           WRITE(stdout,*)  ' Something wrong! '
           WRITE(stdout,*)  ' numk=',numk, ' iknum=',iknum
           CALL errore( 'pw2wannier90', 'Wrong number of k-points', numk)
        ENDIF
        IF(regular_mesh) THEN
           DO i=1,numk
              READ(iun_nnkp,*) xx(1), xx(2), xx(3)
              CALL cryst_to_cart( 1, xx, bg, 1 )
              IF(abs(xx(1)-xk(1,i))>eps6.or. &
                   abs(xx(2)-xk(2,i))>eps6.or. &
                   abs(xx(3)-xk(3,i))>eps6) THEN
                 WRITE(stdout,*)  ' Something wrong! '
                 WRITE(stdout,*) ' k-point ',i,' is wrong'
                 WRITE(stdout,*) xx(1), xx(2), xx(3)
                 WRITE(stdout,*) xk(1,i), xk(2,i), xk(3,i)
                 CALL errore( 'pw2wannier90', 'problems with k-points', i )
              ENDIF
           ENDDO
        ENDIF ! regular mesh check
     ENDIF
     WRITE(stdout,*) ' - K-points are ok'

  ENDIF ! ionode

  ! Broadcast
  CALL mp_bcast(rlatt,ionode_id, world_comm)
  CALL mp_bcast(glatt,ionode_id, world_comm)

  IF (ionode) THEN   ! read from ionode only
     if(noncolin) then
        old_spinor_proj=.false.
        CALL scan_file_to('spinor_projections',found)
        if(.not.found) then
           !try old style projections
           CALL scan_file_to('projections',found)
           if(found) then
              old_spinor_proj=.true.
           else
              CALL errore( 'pw2wannier90', 'Could not find projections block in '&
                 &//trim(seedname)//'.nnkp', 1 )
           endif
        end if
     else
        old_spinor_proj=.false.
        CALL scan_file_to('projections',found)
        if(.not.found) then
           CALL errore( 'pw2wannier90', 'Could not find projections block in '&
              &//trim(seedname)//'.nnkp', 1 )
        endif
     endif
     READ(iun_nnkp,*) n_proj
  ENDIF

  ! Broadcast
  CALL mp_bcast(n_proj,ionode_id, world_comm)
  CALL mp_bcast(old_spinor_proj,ionode_id, world_comm)

  IF(old_spinor_proj)THEN
  WRITE(stdout,'(//," ****** begin WARNING ****** ",/)')
  WRITE(stdout,'(" The pw.x calculation was done with non-collinear spin ")')
  WRITE(stdout,'(" but spinor = T was not specified in the wannier90 .win file!")')
  WRITE(stdout,'(" Please set spinor = T and rerun wannier90.x -pp  ")')
!  WRITE(stdout,'(/," If you are trying to reuse an old nnkp file, you can remove  ")')
!  WRITE(stdout,'(" this check from pw2wannir90.f90 line 870, and recompile. ")')
  WRITE(stdout,'(/," ******  end WARNING  ****** ",//)')
!  CALL errore("pw2wannier90","Spinorbit without spinor=T",1)
  ENDIF

  ! It is not clear if the next instruction is required or not, it probably depend
  ! on the version of wannier90 that was used to generate the nnkp file:
  IF(old_spinor_proj) THEN
     n_wannier=n_proj*2
  ELSE
     n_wannier=n_proj
  ENDIF

  ALLOCATE( center_w(3,n_proj), alpha_w(n_proj), gf(npwx,n_proj), &
       l_w(n_proj), mr_w(n_proj), r_w(n_proj), &
       zaxis(3,n_proj), xaxis(3,n_proj), csph(16,n_proj) )
  if(noncolin.and..not.old_spinor_proj) then
     ALLOCATE( spin_eig(n_proj),spin_qaxis(3,n_proj) )
  endif

  IF (ionode) THEN   ! read from ionode only
     DO iw=1,n_proj
        READ(iun_nnkp,*) (center_w(i,iw), i=1,3), l_w(iw), mr_w(iw), r_w(iw)
        READ(iun_nnkp,*) (zaxis(i,iw),i=1,3),(xaxis(i,iw),i=1,3),alpha_w(iw)
        xnorm = sqrt(xaxis(1,iw)*xaxis(1,iw) + xaxis(2,iw)*xaxis(2,iw) + &
             xaxis(3,iw)*xaxis(3,iw))
        IF (xnorm < eps6) CALL errore ('read_nnkp',' |xaxis| < eps ',1)
        znorm = sqrt(zaxis(1,iw)*zaxis(1,iw) + zaxis(2,iw)*zaxis(2,iw) + &
             zaxis(3,iw)*zaxis(3,iw))
        IF (znorm < eps6) CALL errore ('read_nnkp',' |zaxis| < eps ',1)
        coseno = (xaxis(1,iw)*zaxis(1,iw) + xaxis(2,iw)*zaxis(2,iw) + &
             xaxis(3,iw)*zaxis(3,iw))/xnorm/znorm
        IF (abs(coseno) > eps6) &
             CALL errore('read_nnkp',' xaxis and zaxis are not orthogonal !',1)
        IF (alpha_w(iw) < eps6) &
             CALL errore('read_nnkp',' zona value must be positive', 1)
        ! convert wannier center in cartesian coordinates (in unit of alat)
        CALL cryst_to_cart( 1, center_w(:,iw), at, 1 )
        if(noncolin.and..not.old_spinor_proj) then
           READ(iun_nnkp,*) spin_eig(iw),(spin_qaxis(i,iw),i=1,3)
           xnorm = sqrt(spin_qaxis(1,iw)*spin_qaxis(1,iw) + spin_qaxis(2,iw)*spin_qaxis(2,iw) + &
             spin_qaxis(3,iw)*spin_qaxis(3,iw))
           IF (xnorm < eps6) CALL errore ('read_nnkp',' |xaxis| < eps ',1)
           spin_qaxis(:,iw)=spin_qaxis(:,iw)/xnorm
        endif
     ENDDO
  ENDIF

  ! automatic projections
  IF (ionode) THEN
     CALL scan_file_to('auto_projections',found)
     IF (found) THEN
        READ (iun_nnkp, *) n_wannier
        READ (iun_nnkp, *) tmp_auto

        IF (scdm_proj) THEN
           IF (n_proj > 0) THEN
              WRITE(stdout,'(//, " ****** begin Error message ******",/)')
              WRITE(stdout,'(/," Found a projection block, an auto_projections block",/)')
              WRITE(stdout,'(/," and scdm_proj = T in the input file. These three options are inconsistent.",/)')
              WRITE(stdout,'(/," Please refer to the Wannier90 User guide for correct use of these flags.",/)')
              WRITE(stdout,'(/, " ****** end Error message ******",//)')
              CALL errore( 'pw2wannier90', 'Inconsistent options for projections.', 1 )
           ELSE
              IF (tmp_auto /= 0) CALL errore( 'pw2wannier90', 'Second entry in auto_projections block is not 0. ' // &
              'See Wannier90 User Guide in the auto_projections section for clarifications.', 1 )
           ENDIF
        ELSE IF (atom_proj) THEN
           continue
        ELSE
           ! Fire an error whether or not a projections block is found
           CALL errore( 'pw2wannier90', 'scdm_proj = F and atom_proj = F '&
                &'but found an auto_projections block in '&
                &//trim(seedname)//'.nnkp', 1 )
        ENDIF
     ELSE
        IF (scdm_proj) THEN
           ! Fire an error whether or not a projections block is found
           CALL errore( 'pw2wannier90', 'scdm_proj = T but cannot find an auto_projections block in '&
                &//trim(seedname)//'.nnkp', 1 )
        ENDIF
        IF (atom_proj) THEN
          CALL errore( 'pw2wannier90', 'atom_proj = T but cannot find an auto_projections block in '&
                      &//trim(seedname)//'.nnkp', 1 )
        ENDIF
     ENDIF
  ENDIF

  ! Broadcast
  CALL mp_bcast(n_wannier,ionode_id, world_comm)
  CALL mp_bcast(center_w,ionode_id, world_comm)
  CALL mp_bcast(l_w,ionode_id, world_comm)
  CALL mp_bcast(mr_w,ionode_id, world_comm)
  CALL mp_bcast(r_w,ionode_id, world_comm)
  CALL mp_bcast(zaxis,ionode_id, world_comm)
  CALL mp_bcast(xaxis,ionode_id, world_comm)
  CALL mp_bcast(alpha_w,ionode_id, world_comm)
  if(noncolin.and..not.old_spinor_proj) then
     CALL mp_bcast(spin_eig,ionode_id, world_comm)
     CALL mp_bcast(spin_qaxis,ionode_id, world_comm)
  end if

  WRITE(stdout,'("  - Number of wannier functions is ok (",i3,")")') n_wannier

  IF (.not. scdm_proj) WRITE(stdout,*) ' - All guiding functions are given '
  !
  WRITE(stdout,*)
  WRITE(stdout,*) 'Projections:'
  DO iw=1,n_proj
     WRITE(stdout,'(3f12.6,3i3,f12.6)') &
          center_w(1:3,iw),l_w(iw),mr_w(iw),r_w(iw),alpha_w(iw)
  ENDDO

  IF (ionode) THEN   ! read from ionode only
     CALL scan_file_to('nnkpts',found)
     if(.not.found) then
        CALL errore( 'pw2wannier90', 'Could not find nnkpts block in '&
           &//trim(seedname)//'.nnkp', 1 )
     endif
     READ (iun_nnkp,*) nnb
  ENDIF

  ! Broadcast
  CALL mp_bcast(nnb,ionode_id, world_comm)
  !
  nnbx = max (nnbx, nnb )
  !
  ALLOCATE ( kpb(iknum,nnbx), g_kpb(3,iknum,nnbx),&
             ig_(iknum,nnbx), ig_check(iknum,nnbx) )
  ALLOCATE( zerophase(iknum,nnbx) )
  zerophase = .false.

  !  read data about neighbours
  WRITE(stdout,*)
  WRITE(stdout,*) ' Reading data about k-point neighbours '
  WRITE(stdout,*)

  IF (ionode) THEN
     DO ik=1, iknum
        DO ib = 1, nnb
           READ(iun_nnkp,*) idum, kpb(ik,ib), (g_kpb(ipol,ik,ib), ipol =1,3)
        ENDDO
     ENDDO
  ENDIF

  ! Broadcast
  CALL mp_bcast(kpb,ionode_id, world_comm)
  CALL mp_bcast(g_kpb,ionode_id, world_comm)

  DO ik=1, iknum
     DO ib = 1, nnb
        IF ( (g_kpb(1,ik,ib).eq.0) .and.  &
             (g_kpb(2,ik,ib).eq.0) .and.  &
             (g_kpb(3,ik,ib).eq.0) ) zerophase(ik,ib) = .true.
        g_(:) = REAL( g_kpb(:,ik,ib) )
        CALL cryst_to_cart (1, g_, bg, 1)
        gg_ = g_(1)*g_(1) + g_(2)*g_(2) + g_(3)*g_(3)
        ig_(ik,ib) = 0
        ig = 1
        DO WHILE  (gg(ig) <= gg_ + eps6)
           IF ( (abs(g(1,ig)-g_(1)) < eps6) .and.  &
                (abs(g(2,ig)-g_(2)) < eps6) .and.  &
                (abs(g(3,ig)-g_(3)) < eps6)  ) ig_(ik,ib) = ig
           ig= ig +1
        ENDDO
     ENDDO
  ENDDO
  ig_check(:,:) = ig_(:,:)
  CALL mp_sum( ig_check, intra_pool_comm )
  DO ik=1, iknum
     DO ib = 1, nnb
        IF (ig_check(ik,ib) ==0) &
          CALL errore('read_nnkp', &
                      ' g_kpb vector is not in the list of Gs', 100*ik+ib )
     ENDDO
  ENDDO
  DEALLOCATE (ig_check)

  WRITE(stdout,*) ' All neighbours are found '
  WRITE(stdout,*)

  ALLOCATE( excluded_band(nbnd) )

  IF (ionode) THEN     ! read from ionode only
     CALL scan_file_to('exclude_bands',found)
     if(.not.found) then
        CALL errore( 'pw2wannier90', 'Could not find exclude_bands block in '&
           &//trim(seedname)//'.nnkp', 1 )
     endif
     READ (iun_nnkp,*) nexband
     excluded_band(1:nbnd)=.false.
     DO i=1,nexband
        READ(iun_nnkp,*) indexb
        IF (indexb<1 .or. indexb>nbnd) &
             CALL errore('read_nnkp',' wrong excluded band index ', 1)
        excluded_band(indexb)=.true.
     ENDDO
  ENDIF
  num_bands=nbnd-nexband

  ! Broadcast
  CALL mp_bcast(nexband,ionode_id, world_comm)
  CALL mp_bcast(excluded_band,ionode_id, world_comm)
  CALL mp_bcast(num_bands,ionode_id, world_comm)

  ! 
  ALLOCATE( bvec(3,nnb), xbvec(3,nnb) )
  IF (ionode) THEN
     xbvec = 0
     IF (irr_bz) THEN
        DO i=1, nnb
           xbvec(:,i) = xkc_full(:,kpb(1,i)) - xkc_full(:,1) + g_kpb(:,1,i)
        END DO
        DEALLOCATE(xkc_full)
     ENDIF
  ENDIF
  CALL mp_bcast(xbvec, ionode_id, world_comm)
  bvec = xbvec
  CALL cryst_to_cart(nnb, bvec, bg, +1)

  IF (ionode) CLOSE (iun_nnkp)   ! ionode only

  RETURN
END SUBROUTINE read_nnkp
!
!-----------------------------------------------------------------------
SUBROUTINE scan_file_to (keyword,found)
   !-----------------------------------------------------------------------
   !
   USE wannier, ONLY :iun_nnkp
   USE io_global,  ONLY : stdout
   IMPLICIT NONE
   CHARACTER(len=*), intent(in) :: keyword
   logical, intent(out) :: found
   CHARACTER(len=80) :: line1, line2
!
! by uncommenting the following line the file scan restarts every time
! from the beginning thus making the reading independent on the order
! of data-blocks
!   rewind (iun_nnkp)
!
10 CONTINUE
   READ(iun_nnkp,*,end=20) line1, line2
   IF(line1/='begin')  GOTO 10
   IF(line2/=keyword) GOTO 10
   found=.true.
   RETURN
20 found=.false.
   rewind (iun_nnkp)

END SUBROUTINE scan_file_to
!
!-----------------------------------------------------------------------
SUBROUTINE pw2wan_set_symm (nsym, sr, tvec)
   !-----------------------------------------------------------------------
   !
   ! Uses nkqs and index_sym from module pw2wan, computes rir
   !
   USE symm_base,       ONLY : s, ft, allfrac
   USE fft_base,        ONLY : dffts
   USE cell_base,       ONLY : at, bg
   USE wannier,         ONLY : rir, read_sym
   USE kinds,           ONLY : DP
   USE io_global,       ONLY : stdout
   !
   IMPLICIT NONE
   !
   INTEGER  , intent(in) :: nsym
   REAL(DP) , intent(in) :: sr(3,3,nsym), tvec(3,nsym)
   REAL(DP) :: st(3,3), v(3)
   INTEGER, allocatable :: s_in(:,:,:)
   REAL(DP), allocatable:: ft_in(:,:)
   INTEGER :: nxxs, nr1,nr2,nr3, nr1x,nr2x,nr3x
   INTEGER :: ikq, isym, i,j,k, ri,rj,rk, ir
   LOGICAL :: ispresent(nsym)
   !
   nr1 = dffts%nr1
   nr2 = dffts%nr2
   nr3 = dffts%nr3
   nr1x= dffts%nr1x
   nr2x= dffts%nr2x
   nr3x= dffts%nr3x
   nxxs = nr1x*nr2x*nr3x
   !
   !  sr -> s
   ALLOCATE(s_in(3,3,nsym), ft_in(3,nsym))
   IF(read_sym ) THEN
      IF(allfrac) THEN
         call errore("pw2wan_set_symm", "use_all_frac = .true. + read_sym = .true. not supported", 1)
      END IF
      DO isym = 1, nsym
         !st = transpose( matmul(transpose(bg), sr(:,:,isym)) )
         st = transpose( matmul(transpose(bg), transpose(sr(:,:,isym))) )
         s_in(:,:,isym) = nint( matmul(transpose(at), st) )
         v = matmul(transpose(bg), tvec(:,isym))
         ft_in(1,isym) = v(1)
         ft_in(2,isym) = v(2)
         ft_in(3,isym) = v(3)
      END DO
      IF( any(s(:,:,1:nsym) /= s_in(:,:,1:nsym)) .or. any(ft_in(:,1:nsym) /= ft(:,1:nsym)) ) THEN
         write(stdout,*) " Input symmetry is different from crystal symmetry"
         write(stdout,*)
      END IF
   ELSE
      s_in = s(:,:,1:nsym)
      ft_in = ft(:,1:nsym)
   END IF
   !
   IF(.not. allocated(rir)) ALLOCATE(rir(nxxs,nsym))
   rir = 0
   ispresent(1:nsym) = .false.

   DO isym = 1, nsym
      ! scale sym.ops. with FFT dimensions, check consistency
      ! FIXME: what happens with fractional translations?
      IF ( mod(s_in(2, 1, isym) * nr1, nr2) /= 0 .or. &
           mod(s_in(3, 1, isym) * nr1, nr3) /= 0 .or. &
           mod(s_in(1, 2, isym) * nr2, nr1) /= 0 .or. &
           mod(s_in(3, 2, isym) * nr2, nr3) /= 0 .or. &
           mod(s_in(1, 3, isym) * nr3, nr1) /= 0 .or. &
           mod(s_in(2, 3, isym) * nr3, nr2) /= 0 ) THEN
         CALL errore ('pw2waninit',' smooth grid is not compatible with &
                                   & symmetry: change cutoff',isym)
      ENDIF
      s_in (2,1,isym) = s_in (2,1,isym) * nr1 / nr2
      s_in (3,1,isym) = s_in (3,1,isym) * nr1 / nr3
      s_in (1,2,isym) = s_in (1,2,isym) * nr2 / nr1
      s_in (2,2,isym) = s_in (2,2,isym)
      s_in (3,2,isym) = s_in (3,2,isym) * nr2 / nr3
      s_in (1,3,isym) = s_in (1,3,isym) * nr3 / nr1
      s_in (2,3,isym) = s_in (2,3,isym) * nr3 / nr2
      s_in (3,3,isym) = s_in (3,3,isym)

      DO ir=1, nxxs
         rir(ir,isym) = ir
      ENDDO
      DO k = 1, nr3
         DO j = 1, nr2
            DO i = 1, nr1
               CALL rotate_grid_point (s_in(:,:,isym), (/0,0,0/), i,j,k, &
                    nr1,nr2,nr3, ri,rj,rk)
               !
               ir =   i + ( j-1)*nr1x + ( k-1)*nr1x*nr2x
               rir(ir,isym) = ri + (rj-1)*nr1x + (rk-1)*nr1x*nr2x
            ENDDO
         ENDDO
      ENDDO
   ENDDO
   DEALLOCATE(s_in, ft_in)
END SUBROUTINE pw2wan_set_symm

!-----------------------------------------------------------------------
SUBROUTINE compute_dmn
   !Calculate d_matrix_wann/band for site-symmetry mode given by Rei Sakuma.
   !Contributions for this subroutine:
   !  Yoshiro Nohara (June to July, 2016)
   !-----------------------------------------------------------------------
   !
   USE io_global,  ONLY : stdout, ionode, ionode_id
   USE kinds,           ONLY: DP
   USE wvfct,           ONLY : nbnd, npwx
   USE control_flags,   ONLY : gamma_only
   USE wavefunctions, ONLY : evc, psic, psic_nc
   USE fft_base,        ONLY : dffts, dfftp
   USE fft_interfaces,  ONLY : fwfft, invfft
   USE klist,           ONLY : nkstot, xk, igk_k, ngk
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE gvect,           ONLY : g, ngm, gstart
   USE cell_base,       ONLY : omega, alat, tpiba, at, bg
   USE ions_base,       ONLY : nat, ntyp => nsp, ityp, tau
   USE constants,       ONLY : tpi, bohr => BOHR_RADIUS_ANGS
   USE uspp,            ONLY : nkb, vkb
   USE uspp_param,      ONLY : upf, nh, lmaxq, nhm
   USE becmod,          ONLY : bec_type, becp, calbec, &
                               allocate_bec_type, deallocate_bec_type
   USE mp_pools,        ONLY : intra_pool_comm
   USE mp,              ONLY : mp_sum, mp_bcast
   USE mp_world,        ONLY : world_comm
   USE noncollin_module,ONLY : noncolin, npol
   USE gvecw,           ONLY : gcutw
   USE wannier
   USE symm_base,       ONLY : nsymin=>nsym,srin=>sr,ftin=>ft,invsin=>invs
   USE fft_base,        ONLY : dffts
   USE scatter_mod, ONLY : gather_grid, scatter_grid
   USE uspp_init,            ONLY : init_us_2
   IMPLICIT NONE
   !
   INTEGER, EXTERNAL :: find_free_unit
   !
   complex(DP), parameter :: cmplx_i=(0.0_DP,1.0_DP)
   !
   real(DP), parameter :: p12(3,12)=reshape(                            &
      (/0d0, 0d0, 1.00000000000000d0,                                   &
        0.894427190999916d0, 0d0, 0.447213595499958d0,                  &
        0.276393202250021d0, 0.850650808352040d0, 0.447213595499958d0,  &
       -0.723606797749979d0, 0.525731112119134d0, 0.447213595499958d0,  &
       -0.723606797749979d0, -0.525731112119134d0, 0.447213595499958d0, &
        0.276393202250021d0, -0.850650808352040d0, 0.447213595499958d0, &
        0.723606797749979d0, 0.525731112119134d0, -0.447213595499958d0, &
       -0.276393202250021d0, 0.850650808352040d0, -0.447213595499958d0, &
       -0.894427190999916d0, 0d0, -0.447213595499958d0,                 &
       -0.276393202250021d0, -0.850650808352040d0, -0.447213595499958d0,&
        0.723606797749979d0, -0.525731112119134d0, -0.447213595499958d0,&
        0d0, 0d0, -1.00000000000000d0/),(/3,12/))
   real(DP), parameter :: p20(3,20)=reshape(                            &
      (/0.525731112119134d0, 0.381966011250105d0, 0.850650808352040d0,  &
       -0.200811415886227d0, 0.618033988749895d0, 0.850650808352040d0,  &
       -0.649839392465813d0, 0d0, 0.850650808352040d0,                  &
       -0.200811415886227d0, -0.618033988749895d0, 0.850650808352040d0, &
        0.525731112119134d0, -0.381966011250105d0, 0.850650808352040d0, &
        0.850650808352040d0, 0.618033988749895d0, 0.200811415886227d0,  &
       -0.324919696232906d0, 1.00000000000000d0, 0.200811415886227d0,   &
       -1.05146222423827d0, 0d0, 0.200811415886227d0,                   &
      -0.324919696232906d0, -1.00000000000000d0, 0.200811415886227d0,   &
       0.850650808352040d0, -0.618033988749895d0, 0.200811415886227d0,  &
       0.324919696232906d0, 1.00000000000000d0, -0.200811415886227d0,   &
      -0.850650808352040d0, 0.618033988749895d0, -0.200811415886227d0,  &
      -0.850650808352040d0, -0.618033988749895d0, -0.200811415886227d0, &
       0.324919696232906d0, -1.00000000000000d0, -0.200811415886227d0,  &
       1.05146222423827d0, 0d0, -0.200811415886227d0,                   &
       0.200811415886227d0, 0.618033988749895d0, -0.850650808352040d0,  &
      -0.525731112119134d0, 0.381966011250105d0, -0.850650808352040d0,  &
      -0.525731112119134d0, -0.381966011250105d0, -0.850650808352040d0, &
       0.200811415886227d0, -0.618033988749895d0, -0.850650808352040d0, &
      0.649839392465813d0, 0d0, -0.850650808352040d0/),(/3,20/))
   real(DP), parameter :: pwg(2)=(/2.976190476190479d-2,3.214285714285711d-2/)
   !
   INTEGER :: npw, mmn_tot, ik, ikp, ipol, isym, npwq, i, m, n, ir, jsym
   INTEGER :: ikb, jkb, ih, jh, na, nt, ijkb0, ind, nbt, nir
   INTEGER :: ikevc, ikpevcq, s, counter, iun_dmn, ig, igp, ip, jp, np, iw, jw
   COMPLEX(DP), ALLOCATABLE :: phase(:), aux(:), aux2(:), evcq(:,:), &
                               becp2(:,:), Mkb(:,:), aux_nc(:,:)
   real(DP), ALLOCATABLE    :: rbecp2(:,:),sr(:,:,:)
   COMPLEX(DP), ALLOCATABLE :: qb(:,:,:,:), qgm(:), phs(:,:)
   real(DP), ALLOCATABLE    :: qg(:), workg(:)
   real(DP), ALLOCATABLE    :: ylm(:,:), dxk(:,:), tvec(:,:), dylm(:,:), wws(:,:,:), vps2t(:,:,:), vaxis(:,:,:)
   INTEGER, ALLOCATABLE     :: iks2k(:,:),iks2g(:,:),ik2ir(:),ir2ik(:)
   INTEGER, ALLOCATABLE     :: iw2ip(:),ip2iw(:),ips2p(:,:),invs(:)
   logical, ALLOCATABLE     :: lfound(:)
   COMPLEX(DP)              :: mmn, zdotc, phase1
   real(DP)                 :: arg, g_(3),v1(3),v2(3),v3(3),v4(3),v5(3),err,ermx,dvec(3,32),dwgt(32),dvec2(3,32),dmat(3,3)
   CHARACTER (len=9)        :: cdate,ctime
   CHARACTER (len=header_len) :: header
   LOGICAL                  :: any_uspp
   INTEGER                  :: nn,inn,loop,loop2
   LOGICAL                  :: nn_found
   INTEGER                  :: istart,iend
   INTEGER                  :: ibnd_n, ibnd_m,nsym, nxxs
   COMPLEX(DP), ALLOCATABLE :: psic_all(:), temppsic_all(:)
   LOGICAL                  :: have_sym

   CALL start_clock( 'compute_dmn' )

   IF (wan_mode=='standalone') THEN
      iun_dmn = find_free_unit()
   END IF
   dmat=0d0
   dmat(1,1)=1d0
   dmat(2,2)=1d0
   dmat(3,3)=1d0
   if(read_sym)then
      write(stdout,*) ' Reading symmetry from file '//trim(seedname)//'.sym'
      write(stdout,*) ' '
      if(ionode) then
         inquire(file=trim(seedname)//".sym",exist=have_sym)
         if(.not. have_sym) then
            call errore( 'pw2wannier90', 'Could not find the file '&
               &//trim(seedname)//'.sym', 1 )
         endif
         open(unit=iun_dmn, file=trim(seedname)//".sym",form='formatted')
         read(iun_dmn,*) nsym
      end if
      call mp_bcast(nsym,ionode_id, world_comm)
      allocate(invs(nsym),sr(3,3,nsym),tvec(3,nsym))
      invs=-999
      if(ionode) then
         do isym=1,nsym
            read(iun_dmn,*)
            read(iun_dmn,*) sr(:,:,isym), tvec(:,isym)
         end do
         close(iun_dmn)
      end if
      call mp_bcast(sr, ionode_id, world_comm)
      call mp_bcast(tvec, ionode_id, world_comm)
      do isym=1,nsym
         do jsym=1,nsym
            if(invs(jsym).ge.1) cycle
            v1=matmul(matmul(tvec(:,isym),sr(:,:,jsym))+tvec(:,jsym),bg)
            if(sum(abs(matmul(sr(:,:,isym),sr(:,:,jsym))-dmat))+sum(abs(v1-dble(nint(v1)))).lt.1d-3) then
               invs(isym)=jsym
               invs(jsym)=isym
            end if
         end do
      end do
   else
      nsym=nsymin
      allocate(sr(3,3,nsym),invs(nsym),tvec(3,nsym))
      ! original sr corresponds to transpose(s)
      ! so here we use sr = transpose(original sr)
      do isym=1,nsym
        sr(:,:,isym)=transpose(srin(:,:,isym))
      end do
      invs=invsin(1:nsym)
      tvec=matmul(at(:,:),ftin(:,1:nsym))
      if(ionode)then
         open(unit=iun_dmn, file=trim(seedname)//".sym",form='formatted')
         write(iun_dmn,"(i5)") nsym
         do isym=1,nsym
            write(iun_dmn,*)
            write(iun_dmn,"(1p,3e23.15)") sr(:,:,isym), tvec(:,isym)
         end do
         close(iun_dmn)
      end if
   end if
   do isym=1,nsym
      if(invs(isym).le.0.or.invs(isym).ge.nsym+1) then
         call errore("compute_dmn", "out of range in invs", invs(isym))
      end if
      v1=matmul(matmul(tvec(:,isym),sr(:,:,invs(isym)))+tvec(:,invs(isym)),bg)
      if(sum(abs(matmul(sr(:,:,isym),sr(:,:,invs(isym)))-dmat))+sum(abs(v1-dble(nint(v1)))).gt.1d-3) then
         call errore("compute_dmn", "inconsistent invs", 1)
      end if
   end do

   CALL pw2wan_set_symm ( nsym, sr, tvec )

   any_uspp = any(upf(1:ntyp)%tvanp)

   ALLOCATE( phase(dffts%nnr) )
   ALLOCATE( evcq(npol*npwx,nbnd) )

   IF(noncolin) CALL errore('compute_dmn','Non-collinear not implemented',1)
   IF (gamma_only) CALL errore('compute_dmn','gamma-only not implemented',1)
   IF (wan_mode=='library') CALL errore('compute_dmn','library mode not implemented',1)

   ALLOCATE( aux(npwx) )

   allocate(lfound(max(iknum,ngm)))
   if(.not.allocated(iks2k)) allocate(iks2k(iknum,nsym))
   iks2k=-999 !Sym.op.(isym) moves k(iks2k(ik,isym)) to k(ik) + G(iks2g(ik,isym)).
   do isym=1,nsym
      lfound=.false.
      do ik=1,iknum
         v1=xk(:,ik)
         v2=matmul(sr(:,:,isym),v1)
         do ikp=1,iknum
            if(lfound(ikp)) cycle
            v3=xk(:,ikp)
            v4=matmul(v2-v3,at)
            if(sum(abs(nint(v4)-v4)).lt.1d-5) then
               iks2k(ik,isym)=ikp
               lfound(ikp)=.true.
            end if
            if(iks2k(ik,isym).ge.1) exit
         end do
      end do
   end do
   deallocate(lfound)
   !if(count(iks2k.le.0).ne.0) call errore("compute_dmn", "inconsistent in iks2k", count(iks2k.le.0))
   if(.not.allocated(iks2g)) allocate(iks2g(iknum,nsym))
   iks2g=-999 !See above.
   do isym=1,nsym
      do ik=1,iknum
         ikp=iks2k(ik,isym)
         v1=xk(:,ikp)
         v2=matmul(v1,sr(:,:,isym))
         v3=xk(:,ik)
         do ig=1,ngm
            v4=g(:,ig)
            if(sum(abs(v3+v4-v2)).lt.1d-5) iks2g(ik,isym)=ig
            if(iks2g(ik,isym).ge.1) exit
         end do
      end do
   end do
   !if(count(iks2g.le.0).ne.0) call errore("compute_dmn", "inconsistent in iks2g", count(iks2g.le.0))
   !
   if(.not.allocated(ik2ir)) allocate(ik2ir(iknum))
   ik2ir=-999 !Gives irreducible-k points from regular-k points.
   if(.not.allocated(ir2ik)) allocate(ir2ik(iknum))
   ir2ik=-999 !Gives regular-k points from irreducible-k points.
   allocate(lfound(iknum))
   lfound=.false.
   nir=0
   do ik=1,iknum
      if(lfound(ik)) cycle
      lfound(ik)=.true.
      nir=nir+1
      ir2ik(nir)=ik
      ik2ir(ik)=nir
      do isym=1,nsym
         ikp=iks2k(ik,isym)
         if(lfound(ikp)) cycle
         lfound(ikp)=.true.
         ik2ir(ikp)=nir
      end do
   end do
   deallocate(lfound)
   !write(stdout,"(a)") "ik2ir(ir2ik)="
   !write(stdout,"(10i9)") ik2ir(ir2ik(1:nir))
   !write(stdout,"(a)") "ir2ik(ik2ir)="
   !write(stdout,"(10i9)") ir2ik(ik2ir(1:iknum))

   allocate(iw2ip(n_wannier),ip2iw(n_wannier))
   np=0 !Conversion table between Wannier and position indexes.
   do iw=1,n_wannier
      v1=center_w(:,iw)
      jp=0
      do ip=1,np
         if(sum(abs(v1-center_w(:,ip2iw(ip)))).lt.1d-2) then
            jp=ip
            exit
         end if
      end do
      if(jp.eq.0) then
         np=np+1
         iw2ip(iw)=np
         ip2iw(np)=iw
      else
         iw2ip(iw)=jp
      end if
   end do
   !write(stdout,"(a,10i9)") "iw2ip(ip2iw)="
   !write(stdout,"(10i9)") iw2ip(ip2iw(1:np))
   !write(stdout,"(a)") "ip2iw(iw2ip)="
   !write(stdout,"(10i9)") ip2iw(iw2ip(1:n_wannier))
   allocate(ips2p(np,nsym),lfound(np))
   ips2p=-999 !See below.
   write(stdout,"(a,i5)") "  Number of symmetry operators = ", nsym
   do isym=1,nsym
      write(stdout,"(2x,i5,a)") isym, "-th symmetry operators is"
      write(stdout,"(3f15.7)") sr(:,:,isym), tvec(:,isym) !Writing rotation matrix and translation vector in Cartesian coordinates.
      if(isym.eq.1) then
         dmat=sr(:,:,isym)
         dmat(1,1)=dmat(1,1)-1d0
         dmat(2,2)=dmat(2,2)-1d0
         dmat(3,3)=dmat(3,3)-1d0
         if(sum(abs(dmat))+sum(abs(tvec(:,isym))).gt.1d-5) then
            call errore("compute_dmn", "Error: 1st-symmetry operator is not identical one.", 1)
         end if
      end if
   end do
   do isym=1,nsym
      lfound=.false.
      do ip=1,np
         v1=center_w(:,ip2iw(ip))
         v2=matmul(sr(:,:,isym),(v1+tvec(:,isym)))
         do jp=1,np
            if(lfound(jp)) cycle
            v3=center_w(:,ip2iw(jp))
            v4=matmul(v3-v2,bg)
            if(sum(abs(dble(nint(v4))-v4)).lt.1d-2) then
               lfound(jp)=.true.
               ips2p(ip,isym)=jp
               exit !Sym.op.(isym) moves position(ips2p(ip,isym)) to position(ip) + T, where
            end if                                       !T is given by vps2t(:,ip,isym).
         end do
         if(ips2p(ip,isym).le.0) then
            write(stdout,"(a,3f18.10,a,3f18.10,a)")"  Could not find ",v2,"(",matmul(v2,bg),")"
            write(stdout,"(a,3f18.10,a,3f18.10,a)")"  coming from    ",v1,"(",matmul(v1,bg),")"
            write(stdout,"(a,i5,a               )")"  of Wannier site",ip,"."
            call errore("compute_dmn", "Error: missing Wannier sites, see the output.", 1)
         end if
      end do
   end do
   allocate(vps2t(3,np,nsym)) !See above.
   do isym=1,nsym
      do ip=1,np
         v1=center_w(:,ip2iw(ip))
         jp=ips2p(ip,isym)
         v2=center_w(:,ip2iw(jp))
         v3=matmul(v2,sr(:,:,isym))-tvec(:,isym)
         vps2t(:,ip,isym)=v3-v1
      end do
   end do
   dvec(:,1:12)=p12
   dvec(:,13:32)=p20
   do ip=1,32
      dvec(:,ip)=dvec(:,ip)/sqrt(sum(dvec(:,ip)**2))
   end do
   dwgt(1:12)=pwg(1)
   dwgt(13:32)=pwg(2)
   !write(stdout,*) sum(dwgt) !Checking the weight sum to be 1.
   allocate(dylm(32,5),vaxis(3,3,n_wannier))
   dylm=0d0
   vaxis=0d0
   do ip=1,5
      CALL ylm_wannier(dylm(1,ip),2,ip,dvec,32)
   end do
   !do ip=1,5
   !   write(stdout,"(5f25.15)") (sum(dylm(:,ip)*dylm(:,jp)*dwgt)*2d0*tpi,jp=1,5)
   !end do !Checking spherical integral.
   allocate(wws(n_wannier,n_wannier,nsym))
   wws=0d0
   do iw=1,n_wannier
      call set_u_matrix (xaxis(:,iw),zaxis(:,iw),vaxis(:,:,iw))
   end do
   do isym=1,nsym
      do iw=1,n_wannier
         ip=iw2ip(iw)
         jp=ips2p(ip,isym)
         CALL ylm_wannier(dylm(1,1),l_w(iw),mr_w(iw),matmul(vaxis(:,:,iw),dvec),32)
         do jw=1,n_wannier
            if(iw2ip(jw).ne.jp) cycle
            do ir=1,32
               dvec2(:,ir)=matmul(sr(:,:,isym),dvec(:,ir))
            end do
            CALL ylm_wannier(dylm(1,2),l_w(jw),mr_w(jw),matmul(vaxis(:,:,jw),dvec2),32)
            wws(jw,iw,isym)=sum(dylm(:,1)*dylm(:,2)*dwgt)*2d0*tpi !<Rotated Y(jw)|Not rotated Y(iw)> for sym.op.(isym).
         end do
      end do
   end do
   deallocate(dylm,vaxis)
   do isym=1,nsym
      do iw=1,n_wannier
         err=abs((sum(wws(:,iw,isym)**2)+sum(wws(iw,:,isym)**2))*.5d0-1d0)
         if(err.gt.1d-3) then
            write(stdout,"(a,i5,a,i5,a)") "compute_dmn: Symmetry operator (", isym, &
                    ") could not transform Wannier function (", iw, ")."
            write(stdout,"(a,f15.7,a  )") "compute_dmn: The error is ", err, "."
            call errore("compute_dmn", "Error: missing Wannier functions, see the output.", 1)
         end if
      end do
   end do

   IF (wan_mode=='standalone') THEN
      iun_dmn = find_free_unit()
      CALL date_and_tim( cdate, ctime )
      header='Created on '//cdate//' at '//ctime
      IF (ionode) THEN
         OPEN (unit=iun_dmn, file=trim(seedname)//".dmn",form='formatted')
         WRITE (iun_dmn,*) header
         WRITE (iun_dmn,"(4i9)") nbnd-nexband, nsym, nir, iknum
      ENDIF
   ENDIF

   IF (ionode) THEN
      WRITE (iun_dmn,*)
      WRITE (iun_dmn,"(10i9)") ik2ir(1:iknum)
      WRITE (iun_dmn,*)
      WRITE (iun_dmn,"(10i9)") ir2ik(1:nir)
      do ir=1,nir
         WRITE (iun_dmn,*)
         WRITE (iun_dmn,"(10i9)") iks2k(ir2ik(ir),:)
      enddo
   ENDIF
   allocate(phs(n_wannier,n_wannier))
   phs=(0d0,0d0)
   WRITE(stdout,'(/)')
   WRITE(stdout,'(a,i8)') '  DMN(d_matrix_wann): nir = ',nir
   DO ir=1,nir
      ik=ir2ik(ir)
      WRITE (stdout,'(i8)',advance='no') ir
      IF( MOD(ir,10) == 0 ) WRITE (stdout,*)
      FLUSH(stdout)
      do isym=1,nsym
         do iw=1,n_wannier
            ip=iw2ip(iw)
            jp=ips2p(ip,invs(isym))
            jw=ip2iw(jp)
            v1 = xk(:,iks2k(ik,isym)) - matmul(sr(:,:,isym),xk(:,ik))
            v2 = matmul(v1, sr(:,:,isym))
            phs(iw,iw)=exp(dcmplx(0d0,+sum(vps2t(:,jp,isym)*xk(:,ik))*tpi)) &      !Phase of T.k with lattice vectors T of above.
            *exp(dcmplx(0d0,+sum(tvec(:,isym)*v2)*tpi)) !Phase of t.G with translation vector t(isym).
         end do
         IF (ionode) then
            WRITE (iun_dmn,*)
            WRITE (iun_dmn,"(1p,(' (',e18.10,',',e18.10,')'))") matmul(phs,dcmplx(wws(:,:,isym),0d0))
         end if
      end do
   end do
   if(mod(nir,10) /= 0) WRITE(stdout,*)
   WRITE(stdout,*) ' DMN(d_matrix_wann) calculated'
   deallocate(phs)
   !
   !   USPP
   !
   !
   IF(any_uspp) THEN
      CALL allocate_bec_type ( nkb, nbnd, becp )
      IF (gamma_only) THEN
         call errore("compute_dmn", "gamma-only mode not implemented", 1)
      ELSE
         ALLOCATE ( becp2(nkb,nbnd) )
      ENDIF
   ENDIF
   !
   !     qb is  FT of Q(r)
   !
   nbt = nsym*nir!nnb * iknum
   !
   ALLOCATE( qg(nbt) )
   ALLOCATE (dxk(3,nbt))
   !
   ind = 0
   DO ir=1,nir
      ik=ir2ik(ir)
      DO isym=1,nsym!nnb
         ind = ind + 1
         !        ikp = kpb(ik,ib)
         !
         !        g_(:) = REAL( g_kpb(:,ik,ib) )
         !        CALL cryst_to_cart (1, g_, bg, 1)
         dxk(:,ind) = 0d0!xk(:,ikp) +g_(:) - xk(:,ik)
         qg(ind) = dxk(1,ind)*dxk(1,ind)+dxk(2,ind)*dxk(2,ind)+dxk(3,ind)*dxk(3,ind)
      ENDDO
      !      write (stdout,'(i3,12f8.4)')  ik, qg((ik-1)*nnb+1:ik*nnb)
   ENDDO
   !
   !  USPP
   !
   IF(any_uspp) THEN

      ALLOCATE( ylm(nbt,lmaxq*lmaxq), qgm(nbt) )
      ALLOCATE( qb (nhm, nhm, ntyp, nbt) )
      !
      CALL ylmr2 (lmaxq*lmaxq, nbt, dxk, qg, ylm)
      qg(:) = sqrt(qg(:)) * tpiba
      !
      DO nt = 1, ntyp
         IF (upf(nt)%tvanp ) THEN
            DO ih = 1, nh (nt)
               DO jh = 1, nh (nt)
                  CALL qvan2 (nbt, ih, jh, nt, qg, qgm, ylm)
                  qb (ih, jh, nt, 1:nbt) = omega * qgm(1:nbt)
               ENDDO
            ENDDO
         ENDIF
      ENDDO
      !
      DEALLOCATE (qg, qgm, ylm )
      !
   ENDIF

   WRITE(stdout,'(/)')
   WRITE(stdout,'(a,i8)') '  DMN(d_matrix_band): nir = ',nir
   !
   ALLOCATE( Mkb(nbnd,nbnd) )
   ALLOCATE( workg(npwx) )
   !
   ! Set up variables and stuff needed to rotate wavefunctions
   nxxs = dffts%nr1x *dffts%nr2x *dffts%nr3x
   ALLOCATE(psic_all(nxxs), temppsic_all(nxxs) )
   !
   ind = 0
   DO ir=1,nir
      ik=ir2ik(ir)
      WRITE (stdout,'(i8)',advance='no') ir
      IF( MOD(ir,10) == 0 ) WRITE (stdout,*)
      FLUSH(stdout)
      ikevc = ik + ikstart - 1
      CALL davcio (evc, 2*nwordwfc, iunwfc, ikevc, -1 )
      npw = ngk(ik)
      !
      !  USPP
      !
      IF(any_uspp) THEN
         CALL init_us_2 (npw, igk_k(1,ik), xk(1,ik), vkb)
         ! below we compute the product of beta functions with |psi>
         CALL calbec (npw, vkb, evc, becp)
      ENDIF
      !
      !
      DO isym=1,nsym
         ind = ind + 1
         ikp = iks2k(ik,isym)
         ! read wfc at k+b
         ikpevcq = ikp + ikstart - 1
         !         if(noncolin) then
         !            call davcio (evcq_nc, 2*nwordwfc, iunwfc, ikpevcq, -1 )
         !         else
         CALL davcio (evcq, 2*nwordwfc, iunwfc, ikpevcq, -1 )
         !         end if
         npwq = ngk(ikp)
         do n=1,nbnd
            do ip=1,npwq        !applying translation vector t.
               evcq(ip,n)=evcq(ip,n)*exp(dcmplx(0d0,+sum((matmul(g(:,igk_k(ip,ikp)),sr(:,:,isym))+xk(:,ik))*tvec(:,isym))*tpi))
            end do
         end do
         ! compute the phase
         phase(:) = (0.d0,0.d0)
         ! missing phase G of above is given here and below.
         IF(iks2g(ik,isym) >= 0) phase(dffts%nl(iks2g(ik,isym)))=(1d0,0d0)
         CALL invfft ('Wave', phase, dffts)
         do n=1,nbnd
            if(excluded_band(n)) cycle
            psic(:) = (0.d0, 0.d0)
            psic(dffts%nl(igk_k(1:npwq,ikp))) = evcq(1:npwq,n)
            ! go to real space
            CALL invfft ('Wave', psic, dffts)
#if defined(__MPI)
            ! gather among all the CPUs
            CALL gather_grid(dffts, psic, temppsic_all)
            ! apply rotation
            !psic_all(1:nxxs) = temppsic_all(rir(1:nxxs,isym))
            psic_all(rir(1:nxxs,isym)) = temppsic_all(1:nxxs)
            ! scatter back a piece to each CPU
            CALL scatter_grid(dffts, psic_all, psic)
#else
            psic(rir(1:nxxs, isym)) = psic(1:nxxs)
#endif
            ! apply phase k -> k+G
            psic(1:dffts%nnr) = psic(1:dffts%nnr) * phase(1:dffts%nnr)
            ! go back to G space
            CALL fwfft ('Wave', psic, dffts)
            evcq(1:npw,n)  = psic(dffts%nl (igk_k(1:npw,ik) ) )
         end do
         !
         !  USPP
         !
         IF(any_uspp) THEN
            CALL init_us_2 (npw, igk_k(1,ik), xk(1,ik), vkb)
            ! below we compute the product of beta functions with |psi>
            IF (gamma_only) THEN
               call errore("compute_dmn", "gamma-only mode not implemented", 1)
            ELSE
               CALL calbec ( npw, vkb, evcq, becp2 )
            ENDIF
         ENDIF
         !
         !
         Mkb(:,:) = (0.0d0,0.0d0)
         !
         IF (any_uspp) THEN
            ijkb0 = 0
            DO nt = 1, ntyp
               IF ( upf(nt)%tvanp ) THEN
                  DO na = 1, nat
                     !
                     arg = dot_product( dxk(:,ind), tau(:,na) ) * tpi
                     phase1 = cmplx( cos(arg), -sin(arg) ,kind=DP)
                     !
                     IF ( ityp(na) == nt ) THEN
                        DO jh = 1, nh(nt)
                           jkb = ijkb0 + jh
                           DO ih = 1, nh(nt)
                              ikb = ijkb0 + ih
                              !
                              DO m = 1,nbnd
                                 IF (excluded_band(m)) CYCLE
                                 IF (gamma_only) THEN
                                    call errore("compute_dmn", "gamma-only mode not implemented", 1)
                                 ELSE
                                    DO n=1,nbnd
                                       IF (excluded_band(n)) CYCLE
                                       Mkb(m,n) = Mkb(m,n) + &
                                       phase1 * qb(ih,jh,nt,ind) * &
                                       conjg( becp%k(ikb,m) ) * becp2(jkb,n)
                                    ENDDO
                                 ENDIF
                              ENDDO ! m
                           ENDDO !ih
                        ENDDO !jh
                        ijkb0 = ijkb0 + nh(nt)
                     ENDIF  !ityp
                  ENDDO  !nat
               ELSE  !tvanp
                  DO na = 1, nat
                     IF ( ityp(na) == nt ) ijkb0 = ijkb0 + nh(nt)
                  ENDDO
               ENDIF !tvanp
            ENDDO !ntyp
         ENDIF ! any_uspp
         !
         !
         ! loops on bands
         !
         IF (wan_mode=='standalone') THEN
            IF (ionode) WRITE (iun_dmn,*)
         ENDIF
         !
         DO m=1,nbnd
            IF (excluded_band(m)) CYCLE
            !
            !
            !  Mkb(m,n) = Mkb(m,n) + \sum_{ijI} qb_{ij}^I * e^-i(0*tau_I)
            !             <psi_m,k1| beta_i,k1 > < beta_j,k2 | psi_n,k2 >
            !
            IF (gamma_only) THEN
               call errore("compute_dmn", "gamma-only mode not implemented", 1)
               ELSEIF(noncolin) THEN
               call errore("compute_dmn", "Non-collinear not implemented", 1)
            ELSE
               DO n=1,nbnd
                  IF (excluded_band(n)) CYCLE
                  mmn = zdotc (npw, evc(1,m),1,evcq(1,n),1)
                  CALL mp_sum(mmn, intra_pool_comm)
                  Mkb(m,n) = mmn + Mkb(m,n)
               ENDDO
            ENDIF
         ENDDO   ! m

         ibnd_n = 0
         DO n=1,nbnd
            IF (excluded_band(n)) CYCLE
            ibnd_n = ibnd_n + 1
            ibnd_m = 0
            DO m=1,nbnd
               IF (excluded_band(m)) CYCLE
               ibnd_m = ibnd_m + 1
               IF (wan_mode=='standalone') THEN
                  IF (ionode) WRITE (iun_dmn,"(1p,(' (',e18.10,',',e18.10,')'))")dconjg(Mkb(n,m))
               ELSEIF (wan_mode=='library') THEN
                  call errore("compute_dmn", "library mode not implemented", 1)
               ELSE
                  CALL errore('compute_dmn',' value of wan_mode not recognised',1)
               ENDIF
            ENDDO
         ENDDO
      ENDDO !isym
   ENDDO  !ik

   if(mod(nir,10) /= 0) WRITE(stdout,*)
   WRITE(stdout,*) ' DMN(d_matrix_band) calculated'

   IF (ionode .and. wan_mode=='standalone') CLOSE (iun_dmn)

   DEALLOCATE (Mkb, dxk, phase)
   DEALLOCATE(temppsic_all, psic_all)
   DEALLOCATE(aux)
   DEALLOCATE(evcq)

   IF(any_uspp) THEN
      DEALLOCATE (  qb)
      CALL deallocate_bec_type (becp)
      IF (gamma_only) THEN
         CALL errore('compute_dmn','gamma-only not implemented',1)
      ELSE
         DEALLOCATE (becp2)
      ENDIF
   ENDIF
   !
   CALL stop_clock( 'compute_dmn' )

   RETURN
END SUBROUTINE compute_dmn
!
!-----------------------------------------------------------------------
SUBROUTINE compute_mmn
   !-----------------------------------------------------------------------
   !
   USE io_global,       ONLY : stdout, ionode
   USE kinds,           ONLY : DP
   USE wvfct,           ONLY : nbnd, npwx
   USE control_flags,   ONLY : gamma_only
   USE wavefunctions,   ONLY : evc, psic, psic_nc
   USE fft_base,        ONLY : dffts, dfftp
   USE fft_interfaces,  ONLY : fwfft, invfft
   USE klist,           ONLY : nkstot, xk, igk_k, ngk
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE gvect,           ONLY : g, ngm, gstart
   USE cell_base,       ONLY : omega, alat, tpiba, at, bg
   USE ions_base,       ONLY : nat, ntyp => nsp, ityp, tau
   USE constants,       ONLY : tpi
   USE uspp,            ONLY : nkb, vkb
   USE uspp_param,      ONLY : upf, nh, lmaxq, nhm
   USE becmod,          ONLY : bec_type, becp, calbec, &
                               allocate_bec_type, deallocate_bec_type
   USE mp_pools,        ONLY : intra_pool_comm
   USE mp,              ONLY : mp_sum
   USE noncollin_module,ONLY : noncolin, npol, lspinorb
   USE gvecw,           ONLY : gcutw
   USE wannier
   USE uspp_init,       ONLY : init_us_2

   IMPLICIT NONE
   !
   INTEGER, EXTERNAL :: find_free_unit
   !
   complex(DP), parameter :: cmplx_i=(0.0_DP,1.0_DP)
   !
   INTEGER :: npw, mmn_tot, ik, ikp, ipol, ib, npwq, i, m, n
   INTEGER :: ikb, jkb, ih, jh, na, nt, ijkb0, ind, nbt
   INTEGER :: ikevc, ikpevcq, s, counter
   COMPLEX(DP), ALLOCATABLE :: phase(:), aux(:), aux2(:), evcq(:,:), &
                               becp2(:,:), Mkb(:,:), aux_nc(:,:), becp2_nc(:,:,:)
   real(DP), ALLOCATABLE    :: rbecp2(:,:)
   COMPLEX(DP), ALLOCATABLE :: qb(:,:,:,:), qgm(:), qq_so(:,:,:,:)
   real(DP), ALLOCATABLE    :: qg(:), ylm(:,:), dxk(:,:)
   COMPLEX(DP)              :: mmn, zdotc, phase1
   real(DP)                 :: arg, g_(3)
   CHARACTER (len=9)        :: cdate,ctime
   CHARACTER (len=header_len) :: header
   LOGICAL                  :: any_uspp
   INTEGER                  :: nn,inn,loop,loop2
   LOGICAL                  :: nn_found
   INTEGER                  :: istart,iend
   INTEGER                  :: ibnd_n, ibnd_m
   INTEGER :: ierr

   CALL start_clock( 'compute_mmn' )

   any_uspp = any(upf(1:ntyp)%tvanp)

   ALLOCATE( phase(dffts%nnr), stat=ierr )
   IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating phase', 1)
   ALLOCATE( evcq(npol*npwx,nbnd), stat=ierr)
   IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating evcq', 1)

   IF(noncolin) THEN
      ALLOCATE( aux_nc(npwx,npol), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating aux_nc', 1)
   ELSE
      ALLOCATE( aux(npwx), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating aux', 1)
   ENDIF

   IF (gamma_only) THEN
      ALLOCATE(aux2(npwx), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating aux2', 1)
   END IF

   IF (wan_mode=='library') THEN
      ALLOCATE(m_mat(num_bands, num_bands, nnb, iknum), STAT=ierr)
      IF (ierr /= 0) CALL errore('compute_mmn', 'Error allocating m_mat', 1)
      m_mat = (0.0_dp, 0.0_dp)
   END IF

   IF (wan_mode=='standalone') THEN
      iun_mmn = find_free_unit()
      IF (ionode) OPEN (unit=iun_mmn, file=trim(seedname)//".mmn",form='formatted')
      CALL date_and_tim( cdate, ctime )
      header='Created on '//cdate//' at '//ctime
      IF (ionode) THEN
         WRITE (iun_mmn,*) header
         WRITE (iun_mmn,*) nbnd-nexband, iknum, nnb
      ENDIF
   ENDIF

   !
   !   USPP
   !
   !
   IF(any_uspp) THEN
      CALL allocate_bec_type ( nkb, nbnd, becp )
      IF (gamma_only) THEN
         ALLOCATE ( rbecp2(nkb,nbnd), STAT=ierr )
         IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating rbecp2', 1)
      else if (noncolin) then
         ALLOCATE ( becp2_nc(nkb,2,nbnd), STAT=ierr )
         IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating becp2_nc', 1)
      ELSE
         ALLOCATE ( becp2(nkb,nbnd), STAT=ierr )
         IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating becp2', 1)
      ENDIF
      !
      !     qb is  FT of Q(r)
      !
      nbt = nnb * iknum
      !
      ALLOCATE( qg(nbt), STAT=ierr )
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating qg', 1)
      ALLOCATE (dxk(3,nbt), STAT=ierr )
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating dxk', 1)
      !
      ind = 0
      DO ik=1,iknum
         DO ib=1,nnb
            ind = ind + 1
            ikp = kpb(ik,ib)
            !
            g_(:) = REAL( g_kpb(:,ik,ib) )
            CALL cryst_to_cart (1, g_, bg, 1)
            dxk(:,ind) = xk(:,ikp) +g_(:) - xk(:,ik)
            qg(ind) = dxk(1,ind)*dxk(1,ind)+dxk(2,ind)*dxk(2,ind)+dxk(3,ind)*dxk(3,ind)
         ENDDO
!         write (stdout,'(i3,12f8.4)')  ik, qg((ik-1)*nnb+1:ik*nnb)
      ENDDO

      ALLOCATE( ylm(nbt,lmaxq*lmaxq), qgm(nbt), STAT=ierr )
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating ylm, qgm', 1)
      ALLOCATE( qb (nhm, nhm, ntyp, nbt), STAT=ierr )
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating qb', 1)
      ALLOCATE( qq_so (nhm, nhm, 4, ntyp), STAT=ierr )
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating qq_so', 1)
      !
      CALL ylmr2 (lmaxq*lmaxq, nbt, dxk, qg, ylm)
      qg(:) = sqrt(qg(:)) * tpiba
      !
      DO nt = 1, ntyp
         IF (upf(nt)%tvanp ) THEN
            DO ih = 1, nh (nt)
               DO jh = 1, nh (nt)
                  CALL qvan2 (nbt, ih, jh, nt, qg, qgm, ylm)
                  qb (ih, jh, nt, 1:nbt) = omega * qgm(1:nbt)
               ENDDO
            ENDDO
         ENDIF
      ENDDO
      !
      DEALLOCATE (qg, qgm, ylm )
      !
   ENDIF

   WRITE(stdout,'(a,i8)') '  MMN: iknum = ',iknum
   !
   ALLOCATE( Mkb(nbnd,nbnd), stat=ierr )
   IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating Mkb', 1)
   !

   ind = 0
   DO ik=1,iknum
      WRITE (stdout,'(i8)',advance='no') ik
      IF( MOD(ik,10) == 0 ) WRITE (stdout,*)
      FLUSH(stdout)
      ikevc = ik + ikstart - 1
      CALL davcio (evc, 2*nwordwfc, iunwfc, ikevc, -1)
      npw = ngk(ik)
      !
      !  USPP
      !
      IF(any_uspp) THEN
         CALL init_us_2 (npw, igk_k(1,ik), xk(1,ik), vkb)
         ! below we compute the product of beta functions with |psi>
         CALL calbec (npw, vkb, evc, becp)
      ENDIF
      !
      !
      !do ib=1,nnb(ik)
      DO ib=1,nnb
         ind = ind + 1
         ikp = kpb(ik,ib)
! read wfc at k+b
         ikpevcq = ikp + ikstart - 1
!         if(noncolin) then
!            call davcio (evcq_nc, 2*nwordwfc, iunwfc, ikpevcq, -1 )
!         else
            CALL davcio (evcq, 2*nwordwfc, iunwfc, ikpevcq, -1 )
!         end if
! compute the phase
         IF (.not.zerophase(ik,ib)) THEN
            phase(:) = (0.d0,0.d0)
            IF ( ig_(ik,ib)>0) phase( dffts%nl(ig_(ik,ib)) ) = (1.d0,0.d0)
            CALL invfft ('Wave', phase, dffts)
         ENDIF
         !
         !  USPP
         !
         npwq = ngk(ikp)
         IF(any_uspp) THEN
            CALL init_us_2 (npwq, igk_k(1,ikp), xk(1,ikp), vkb)
            ! below we compute the product of beta functions with |psi>
            IF (gamma_only) THEN
               CALL calbec ( npwq, vkb, evcq, rbecp2 )
            else if (noncolin) then
               CALL calbec ( npwq, vkb, evcq, becp2_nc )

               if (lspinorb) then
                  qq_so = (0.0d0, 0.0d0)
                  call transform_qq_so(qb(:,:,:,ind), qq_so)
               endif

            ELSE
               CALL calbec ( npwq, vkb, evcq, becp2 )
            ENDIF
         ENDIF
         !
         !
         Mkb(:,:) = (0.0d0,0.0d0)
         !
         ! loops on bands
         !
         IF (wan_mode=='standalone') THEN
            IF (ionode) WRITE (iun_mmn,'(7i5)') ik, ikp, (g_kpb(ipol,ik,ib), ipol=1,3)
         ENDIF
         !
         DO m=1,nbnd
            IF (excluded_band(m)) CYCLE
            !
            IF(noncolin) THEN
               psic_nc(:,:) = (0.d0, 0.d0)
               DO ipol=1,2!npol
                  istart=(ipol-1)*npwx+1
                  iend=istart+npw-1
                  psic_nc(dffts%nl (igk_k(1:npw,ik) ),ipol ) = evc(istart:iend, m)
                  IF (.not.zerophase(ik,ib)) THEN
                     CALL invfft ('Wave', psic_nc(:,ipol), dffts)
                     psic_nc(1:dffts%nnr,ipol) = psic_nc(1:dffts%nnr,ipol) * &
                                                 phase(1:dffts%nnr)
                     CALL fwfft ('Wave', psic_nc(:,ipol), dffts)
                  ENDIF
                  aux_nc(1:npwq,ipol) = psic_nc(dffts%nl(igk_k(1:npwq,ikp)), ipol)
               ENDDO
            ELSE
               psic(:) = (0.d0, 0.d0)
               psic(dffts%nl (igk_k (1:npw,ik) ) ) = evc (1:npw, m)
               IF(gamma_only) psic(dffts%nlm(igk_k(1:npw,ik) ) ) = conjg(evc (1:npw, m))
               IF (.not.zerophase(ik,ib)) THEN
                  CALL invfft ('Wave', psic, dffts)
                  psic(1:dffts%nnr) = psic(1:dffts%nnr) * phase(1:dffts%nnr)
                  CALL fwfft ('Wave', psic, dffts)
               ENDIF
               aux(1:npwq) = psic(dffts%nl(igk_k(1:npwq,ikp)))
            ENDIF
            IF(gamma_only) THEN
               IF (gstart==2) psic(dffts%nlm(1)) = (0.d0,0.d0)
               aux2(1:npwq) = conjg(psic(dffts%nlm(igk_k(1:npwq,ikp) ) ) )
            ENDIF
            !
            !  Mkb(m,n) = Mkb(m,n) + \sum_{ijI} qb_{ij}^I * e^-i(b*tau_I)
            !             <psi_m,k1| beta_i,k1 > < beta_j,k2 | psi_n,k2 >
            !
            IF (gamma_only) THEN
               DO n=1,m ! Mkb(m,n) is symmetric in m and n for gamma_only case
                  IF (excluded_band(n)) CYCLE
                  mmn = zdotc (npwq, aux,1,evcq(1,n),1) &
                       + conjg(zdotc(npwq,aux2,1,evcq(1,n),1))
                  Mkb(m,n) = mmn + Mkb(m,n)
                  IF (m/=n) Mkb(n,m) = Mkb(m,n) ! fill other half of matrix by symmetry
               ENDDO
            ELSEIF(noncolin) THEN
               DO n=1,nbnd
                  IF (excluded_band(n)) CYCLE
                  mmn=(0.d0, 0.d0)
!                  do ipol=1,2
!                     mmn = mmn+zdotc (npwq, aux_nc(1,ipol),1,evcq_nc(1,ipol,n),1)
                  mmn = mmn + zdotc (npwq, aux_nc(1,1),1,evcq(1,n),1) &
                       + zdotc (npwq, aux_nc(1,2),1,evcq(npwx+1,n),1)
!                  end do
                  Mkb(m,n) = mmn + Mkb(m,n)
               ENDDO
            ELSE
               DO n=1,nbnd
                  IF (excluded_band(n)) CYCLE
                  mmn = zdotc (npwq, aux,1,evcq(1,n),1)
                  Mkb(m,n) = mmn + Mkb(m,n)
               ENDDO
            ENDIF
         ENDDO   ! m
         !
         ! updating of the elements of the matrix Mkb
         !
         DO n=1,nbnd
            IF (excluded_band(n)) CYCLE
            CALL mp_sum(Mkb(:,n), intra_pool_comm)
         ENDDO
         !
         IF (any_uspp) THEN
            ijkb0 = 0
            DO nt = 1, ntyp
               IF ( upf(nt)%tvanp ) THEN
                  DO na = 1, nat
                     !
                     arg = dot_product( dxk(:,ind), tau(:,na) ) * tpi
                     phase1 = cmplx( cos(arg), -sin(arg) ,kind=DP)
                     !
                     IF ( ityp(na) == nt ) THEN
                        DO jh = 1, nh(nt)
                           jkb = ijkb0 + jh
                           DO ih = 1, nh(nt)
                              ikb = ijkb0 + ih
                              !
                              DO m = 1,nbnd
                                 IF (excluded_band(m)) CYCLE
                                 IF (gamma_only) THEN
                                    DO n=1,m ! Mkb(m,n) is symmetric in m and n for gamma_only case
                                       IF (excluded_band(n)) CYCLE
                                       Mkb(m,n) = Mkb(m,n) + &
                                            phase1 * qb(ih,jh,nt,ind) * &
                                            becp%r(ikb,m) * rbecp2(jkb,n)
                                       ! fill other half of matrix by symmetry
                                       IF (m/=n) Mkb(n,m) = Mkb(m,n)
                                    ENDDO
                                 else if (noncolin) then
                                    DO n=1,nbnd
                                       IF (excluded_band(n)) CYCLE
                                       if (lspinorb) then
                                          Mkb(m,n) = Mkb(m,n) + &
                                            phase1 * ( &
                                               qq_so(ih,jh,1,nt) * conjg( becp%nc(ikb, 1, m) ) * becp2_nc(jkb, 1, n) &
                                             + qq_so(ih,jh,2,nt) * conjg( becp%nc(ikb, 1, m) ) * becp2_nc(jkb, 2, n) &
                                             + qq_so(ih,jh,3,nt) * conjg( becp%nc(ikb, 2, m) ) * becp2_nc(jkb, 1, n) &
                                             + qq_so(ih,jh,4,nt) * conjg( becp%nc(ikb, 2, m) ) * becp2_nc(jkb, 2, n) &
                                             )
                                       else
                                          Mkb(m,n) = Mkb(m,n) + &
                                            phase1 * qb(ih,jh,nt,ind) * &
                                            (conjg( becp%nc(ikb, 1, m) ) * becp2_nc(jkb, 1, n) &
                                              + conjg( becp%nc(ikb, 2, m) ) * becp2_nc(jkb, 2, n) )
                                       endif
                                    ENDDO
                                 ELSE
                                    DO n=1,nbnd
                                       IF (excluded_band(n)) CYCLE
                                       Mkb(m,n) = Mkb(m,n) + &
                                            phase1 * qb(ih,jh,nt,ind) * &
                                            conjg( becp%k(ikb,m) ) * becp2(jkb,n)
                                    ENDDO
                                 ENDIF
                              ENDDO ! m
                           ENDDO !ih
                        ENDDO !jh
                        ijkb0 = ijkb0 + nh(nt)
                     ENDIF  !ityp
                  ENDDO  !nat
               ELSE  !tvanp
                  DO na = 1, nat
                     IF ( ityp(na) == nt ) ijkb0 = ijkb0 + nh(nt)
                  ENDDO
               ENDIF !tvanp
            ENDDO !ntyp
         ENDIF ! any_uspp
         !
         ibnd_n = 0
         DO n=1,nbnd
            IF (excluded_band(n)) CYCLE
            ibnd_n = ibnd_n + 1
            ibnd_m = 0
            DO m=1,nbnd
               IF (excluded_band(m)) CYCLE
               ibnd_m = ibnd_m + 1
               IF (wan_mode=='standalone') THEN
                  IF (ionode) WRITE (iun_mmn,'(2f18.12)') Mkb(m,n)
               ELSEIF (wan_mode=='library') THEN
                  m_mat(ibnd_m,ibnd_n,ib,ik) = Mkb(m,n)
               ELSE
                  CALL errore('compute_mmn',' value of wan_mode not recognised',1)
               ENDIF
            ENDDO
         ENDDO
         !
      ENDDO !ib
   ENDDO  !ik

   IF (ionode .and. wan_mode=='standalone') CLOSE (iun_mmn)

   IF (gamma_only) DEALLOCATE(aux2)
   DEALLOCATE (Mkb, phase)
   IF (any_uspp) DEALLOCATE (dxk)
   IF(noncolin) THEN
      DEALLOCATE(aux_nc)
   ELSE
      DEALLOCATE(aux)
   ENDIF
   DEALLOCATE(evcq)

   IF(any_uspp) THEN
      DEALLOCATE (qb)
      DEALLOCATE (qq_so)
      CALL deallocate_bec_type (becp)
      IF (gamma_only) THEN
          DEALLOCATE (rbecp2)
       else if (noncolin) then
         deallocate (becp2_nc)
       ELSE
          DEALLOCATE (becp2)
       ENDIF
    ENDIF
!
   WRITE(stdout,'(/)')
   WRITE(stdout,*) ' MMN calculated'

   CALL stop_clock( 'compute_mmn' )

   RETURN
END SUBROUTINE compute_mmn

SUBROUTINE compute_mmn_ibz
   !-----------------------------------------------------------------------
   !
   USE io_global,       ONLY : stdout, ionode
   USE kinds,           ONLY : DP
   USE wvfct,           ONLY : nbnd, npwx
   USE control_flags,   ONLY : gamma_only
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE wavefunctions,   ONLY : evc, psic
   USE fft_base,        ONLY : dffts
   !USE klist,           ONLY : nkstot, xk, ngk
   USE klist,           ONLY : ngk, igk_k, xk
   USE noncollin_module,ONLY : noncolin, npol, lspinorb
   USE ions_base,       ONLY : nat, ntyp => nsp, ityp, tau
   USE constants,       ONLY : tpi
   USE cell_base,       ONLY : at
   USE uspp,            ONLY : nkb, vkb, okvan
   USE uspp_param,      ONLY : upf, nh, nhm
   USE becmod,          ONLY : bec_type, becp, calbec, &
                               allocate_bec_type, deallocate_bec_type
   USE symm_base,       ONLY : invs
   USE mp,              ONLY : mp_sum
   USE mp_pools,        ONLY : intra_pool_comm
   USE wannier,         ONLY : iknum, ikstart, nnb, nexband, excluded_band, &
                               seedname, bvec, header_len
   USE uspp_init,       ONLY : init_us_2
   !
   IMPLICIT NONE
   !
   INTEGER, EXTERNAL      :: find_free_unit
   COMPLEX(DP), EXTERNAL  :: zdotc
   !
   complex(DP), parameter :: cmplx_i=(0.0_DP,1.0_DP)
   !
   INTEGER                  :: ik, ib, ikp, ikevc1, ikevc2, isym, m, n, iun_mmn
   INTEGER                  :: ih, jh, nt, na, ikb, jkb, ijkb0
   INTEGER                  :: npw, npwq
   INTEGER, ALLOCATABLE     :: rir(:,:)
   CHARACTER (len=9)        :: cdate, ctime
   CHARACTER (len=header_len) :: header
   REAL(DP)                 :: kdiff(3), skp(3), arg, kpb(3)
   REAL(DP), ALLOCATABLE    :: xkc(:,:)
   COMPLEX(DP)              :: mmn, phase1
   COMPLEX(DP), ALLOCATABLE :: Mkb(:,:), evc2(:,:), evc_kb(:,:)
   COMPLEX(DP), ALLOCATABLE :: qb(:,:,:,:), qq_so(:,:,:,:,:)
   TYPE(bec_type)           :: becp1, becp2
   ! symmetry operation with time reversal symmetry
   INTEGER                  :: nsym2, s2(3,3,96), invs2(96), t_rev2(96), t_rev_spin(2,2)
   REAL(DP)                 :: sr2(3,3,96), ft2(3,96)
   !
   CALL start_clock( 'compute_immn' )
   !
   CALL setup_symm_time_reversal()
   !
   CALL pw2wan_set_symm_with_time_reversal( dffts%nr1, dffts%nr2, dffts%nr3, dffts%nr1x, dffts%nr2x, dffts%nr3x )
   !
   !
   CALL save_sym_info()
   !
   iun_mmn = find_free_unit()
   CALL date_and_tim( cdate, ctime )
   header='IBZ Mmn created on '//cdate//' at '//ctime
   IF (ionode) THEN
      OPEN (unit=iun_mmn, file=trim(seedname)//".immn",form='formatted')
      WRITE (iun_mmn,*) header
      WRITE (iun_mmn,*) nbnd-nexband, iknum, nnb
   ENDIF
   !
   WRITE(stdout,'(a,i8)') '  MMN: iknum = ',iknum
   !
   IF (okvan) THEN
      ALLOCATE(qb(nhm, nhm, ntyp, nnb), qq_so(nhm, nhm, 4, ntyp, nnb))
      CALL init_qb_so(qb, qq_so)
      CALL allocate_bec_type(nkb, nbnd, becp)
      CALL allocate_bec_type(nkb, nbnd, becp1)
      CALL allocate_bec_type(nkb, nbnd, becp2)
   END IF
   !
   ALLOCATE( evc2(npwx*npol,nbnd), evc_kb(npwx*npol,nbnd), Mkb(nbnd,nbnd) )
   !
   ! calculate <psi_k | e^{-ibr} | psi_k+b>
   ! ik : <psi_k|
   DO ik=1, iknum
      WRITE (stdout,'(i8)',advance='no') ik
      IF( MOD(ik,10) == 0 ) WRITE (stdout,*)
      FLUSH(stdout)
      ikevc1 = ik + ikstart - 1
      CALL davcio (evc, 2*nwordwfc, iunwfc, ikevc1, -1 )
      npw = ngk(ik)
      !
      !  USPP
      !
      IF (okvan) THEN
         ! becp for k
         CALL init_us_2 (npw, igk_k(1,ik), xk(1,ik), vkb)
         CALL calbec (npw, vkb, evc, becp)
      END IF
      !
      ! |psi_k+b>,  k+b = xk(:,ik) + xbvec(:,ib) = s.k + G = s.xk(:,ikp) + kdiff
      DO ib=1, nnb
         CALL kpb_search(ik, ib, ikp, isym, kdiff, skp)
         IF (ionode) WRITE (iun_mmn,'(7i5)') ik, ikp, (nint(kdiff(n)), n=1,3)
         ikevc2 = ikp + ikstart - 1
         CALL davcio (evc2, 2*nwordwfc, iunwfc, ikevc2, -1 )
         CALL rotate_evc(isym, ikp, ik, kdiff, evc2, evc_kb)
         !
         ! USPP
         !
         IF (okvan) THEN
            ! calculate becp1 = <beta|psi_kp> and rotate => becp2
            npwq = ngk(ikp)
            kpb = skp + kdiff
            call cryst_to_cart(1, kpb, at, 1)
            call cryst_to_cart(1, skp, at, 1)
            CALL init_us_2 (npwq, igk_k(1,ikp), xk(1,ikp), vkb)
            CALL calbec ( npwq, vkb, evc2, becp1 )
            ! t_rev2(isym) = 0 or 1  ==>  1-2*t_rev2(isym) = 1 or -1
            CALL rotate_becp(isym, 1-2*t_rev2(isym), xk(1,ikp), skp, becp1, becp2)
         END IF
         !
         ! plane wave part
         !
         Mkb = (0.0d0,0.0d0)
         DO n=1, nbnd
            IF (excluded_band(n)) CYCLE
            DO m=1, nbnd
               IF (excluded_band(m)) CYCLE
               IF (noncolin) THEN
                  mmn = zdotc (npw, evc(1,m),1,evc_kb(1,n),1) &
                      + zdotc (npw, evc(npwx+1,m),1,evc_kb(npwx+1,n),1)
               ELSE
                  mmn = zdotc (npw, evc(1,m),1,evc_kb(1,n),1)
               END IF
               !CALL mp_sum(mmn, intra_pool_comm)
               Mkb(m,n) = mmn
            END DO
         END DO
         CALL mp_sum(Mkb, intra_pool_comm)
         !
         ! USPP/PAW part
         !
         IF (okvan) THEN
            ijkb0 = 0
            DO nt = 1, ntyp
               IF ( upf(nt)%tvanp ) THEN
                  DO na = 1, nat
                     !
                     ! e^{-ibr}
                     arg = dot_product( bvec(:,ib), tau(:,na) ) * tpi
                     phase1 = cmplx( cos(arg), -sin(arg) ,kind=DP)
                     !
                     IF ( ityp(na) == nt ) THEN
                        DO jh = 1, nh(nt)
                           jkb = ijkb0 + jh
                           DO ih = 1, nh(nt)
                              ikb = ijkb0 + ih
                              !
                              DO m = 1,nbnd
                                 IF (excluded_band(m)) CYCLE
                                 DO n = 1,nbnd
                                    IF (excluded_band(n)) CYCLE
                                    IF (gamma_only) THEN
                                       mmn = phase1 * qb(ih,jh,nt,ib) * becp%r(ikb,m) * becp2%r(jkb,n)
                                    ELSE IF (noncolin) THEN
                                       IF (lspinorb) THEN
                                          mmn = phase1 * ( &
                                               qq_so(ih,jh,1,nt,ib) * conjg( becp%nc(ikb, 1, m) ) * becp2%nc(jkb, 1, n) &
                                             + qq_so(ih,jh,2,nt,ib) * conjg( becp%nc(ikb, 1, m) ) * becp2%nc(jkb, 2, n) &
                                             + qq_so(ih,jh,3,nt,ib) * conjg( becp%nc(ikb, 2, m) ) * becp2%nc(jkb, 1, n) &
                                             + qq_so(ih,jh,4,nt,ib) * conjg( becp%nc(ikb, 2, m) ) * becp2%nc(jkb, 2, n) &
                                             )
                                       ELSE
                                          mmn =  phase1 * qb(ih,jh,nt,ib) * &
                                            (conjg( becp%nc(ikb, 1, m) ) * becp2%nc(jkb, 1, n) &
                                           + conjg( becp%nc(ikb, 2, m) ) * becp2%nc(jkb, 2, n) )
                                       END IF
                                    ELSE
                                       mmn = phase1 * qb(ih,jh,nt,ib) * conjg( becp%k(ikb,m) ) * becp2%k(jkb,n)
                                    END IF
                                    Mkb(m,n) = Mkb(m,n) + mmn
                                 ENDDO
                              ENDDO ! m
                           ENDDO !ih
                        ENDDO !jh
                        ijkb0 = ijkb0 + nh(nt)
                     ENDIF  !ityp
                  ENDDO  !nat
               ELSE  !tvanp or tpanp
                  DO na = 1, nat
                     IF ( ityp(na) == nt ) ijkb0 = ijkb0 + nh(nt)
                  ENDDO
               ENDIF !tvanp
            ENDDO !ntyp
         END IF !okvan
         !
         ! write Mkb(m,n) => prefix.mmn
         !
         DO n=1, nbnd
            IF (excluded_band(n)) CYCLE
            DO m=1, nbnd
               IF (excluded_band(m)) CYCLE
               IF (ionode) WRITE (iun_mmn,'(2f18.12)') Mkb(m,n)
            END DO
         END DO
         !
      END DO !ib
      !
   END DO !ik
   !
   IF (okvan) THEN
      CALL deallocate_bec_type(becp)
      CALL deallocate_bec_type(becp1)
      CALL deallocate_bec_type(becp2)
   END IF
   !
   IF (ionode) CLOSE(iun_mmn)
   WRITE(stdout,'(/)')
   WRITE(stdout,*) ' IBZ MMN calculated'
   !
   CALL stop_clock( 'compute_immn' )
   !
   CONTAINS
   !
   SUBROUTINE setup_symm_time_reversal()
      ! generate symmetry operation with time reversal symmetry
      ! 1..nsym => 1..2*nsym  if time reversal
      ! nsym, s, ft, t_rev, invs, sr ==> nsym2, s2, ft2, t_rev2, invs2, sr2
      USE symm_base,       ONLY : nsym, s, ft, time_reversal, t_rev, invs, sr
      s2(:,:,1:nsym) = s(:,:,1:nsym)
      sr2(:,:,1:nsym) = sr(:,:,1:nsym)
      ft2(:,1:nsym) = ft(:,1:nsym)
      t_rev2(1:nsym) = t_rev(1:nsym)
      invs2(1:nsym) = invs(1:nsym)
      nsym2 = nsym
      ! t_rev_spin = -i sigma_y (for time reversal)
      t_rev_spin = 0
      t_rev_spin(1,2) = -1
      t_rev_spin(2,1) = 1
      IF (time_reversal) THEN
         nsym2 = 2*nsym
         s2(:,:,nsym+1:2*nsym) = s(:,:,1:nsym)
         sr2(:,:,nsym+1:2*nsym) = sr(:,:,1:nsym)
         ft2(:,nsym+1:2*nsym) = ft(:,1:nsym)
         t_rev2(nsym+1:2*nsym) = 1
         invs2(nsym+1:2*nsym) = invs(1:nsym) + nsym
      END IF
   END SUBROUTINE
   !
   SUBROUTINE save_sym_info()
      !
      ! save symmetry information, representation matrix, repmat(nbnd, nbnd, nsym) and rotation matrix, rotmat(nwan, nwan, nsym)
      ! repmat: representation of little group G_k
      ! rotmat: rotation matrix for initial Wannier function
      !
      USE klist,           ONLY : nkstot
      USE wvfct,           ONLY : nbnd
      USE symm_base,       ONLY : nsym, time_reversal, sname
      USE start_k,         ONLY : k1, k2, k3, nk1, nk2, nk3
      USE wannier,         ONLY : seedname, n_wannier, nexband
      !
      INTEGER, EXTERNAL        :: find_free_unit
      !
      INTEGER                  :: i, m, n, iun_sym, mi, ni, a, ncount
      CHARACTER (len=9)        :: cdate,ctime
      REAL(DP)                 :: srt(3,3)
      COMPLEX(DP)              :: tr, u_spin(2,2)
      COMPLEX(DP), ALLOCATABLE :: rotmat(:,:,:), repmat(:,:,:,:)
      !
      ALLOCATE( repmat(nbnd, nbnd, nsym2, nkstot) )
      CALL get_representation_matrix(repmat)
      !
      ALLOCATE( rotmat(n_wannier, n_wannier, nsym2) )
      CALL get_rotation_matrix(rotmat)
      !
      ! save repmat
      !
      iun_sym = find_free_unit()
      CALL date_and_tim( cdate, ctime )
      IF (ionode) THEN
         OPEN(unit=iun_sym, file=trim(seedname)//".isym", form='formatted')
         !
         ! save symmetry operation
         !
         WRITE (iun_sym,*) 'Symmetry information created on  '//cdate//' at '//ctime
         IF (noncolin) THEN
            WRITE (iun_sym,*) nsym2, 1
         ELSE
            WRITE (iun_sym,*) nsym2, 0
         END IF
         DO i=1, nsym2
            IF (i > nsym) THEN
               WRITE (iun_sym,'(i3,":  ",a, "+T")') i, sname(i-nsym)
            ELSE
               WRITE (iun_sym,'(i3,":  ",a)') i, sname(i)
            END IF
            DO a=1, 3
               write(iun_sym,'(3i10)') s2(a,:,i)
            END DO
            write(iun_sym,'(3f20.12)') ft2(:,i)
            write(iun_sym,*) t_rev2(i)
            !
            IF (noncolin) THEN
               srt = transpose(sr2(:,:,i))
               CALL find_u(srt, u_spin)
               write(iun_sym,'(2f20.12)') (u_spin(1,a), a=1,2)
               write(iun_sym,'(2f20.12)') (u_spin(2,a), a=1,2)
            END IF
            !
            write(iun_sym,*) invs2(i)
         END DO

         write(iun_sym, *)
         WRITE (iun_sym,*) 'K points'
         write(iun_sym,'(3i10)') iknum
         DO i=1, iknum
           write(iun_sym, '(3f16.10)') xkc(:,i)
         END DO
         !
         ! save representation matrix
         !
         write(iun_sym, *)
         WRITE (iun_sym,*) 'Representation matrix of G_k'
         ncount = 0
         DO ik=1, nkstot
            DO isym=1, nsym2
               IF (.not. all(repmat(:,:,isym,ik) == 0)) ncount = ncount + 1
            END DO
         END DO
         WRITE (iun_sym,'(3i10)') nbnd - nexband, ncount
         DO ik=1, nkstot
            DO isym=1, nsym2
               IF (all(repmat(:,:,isym,ik) == 0)) CYCLE
               ncount = count(repmat(:,:,isym,ik) /= 0)
               WRITE(iun_sym, *) ik, isym, ncount
               !tr = 0
               !DO m=1, nbnd
               !   tr = tr + repmat(m,m,isym,ik)
               !END DO
               !WRITE(iun_sym, '(2f20.10)') real(tr), aimag(tr)
               mi = 0
               DO m=1, nbnd
                  IF (excluded_band(m)) CYCLE
                  mi = mi + 1
                  ni = 0
                  DO n=1, nbnd
                     IF (excluded_band(n)) CYCLE
                     ni = ni + 1
                     IF (repmat(m,n,isym,ik) == 0) CYCLE
                     WRITE(iun_sym, '(2i5,2f22.15)') mi, ni, real(repmat(m,n,isym,ik)), aimag(repmat(m,n,isym,ik))
                  END DO
               END DO
            END DO
         END DO
         !
         ! save rotation matrix
         !
         write(iun_sym, *)
         WRITE(iun_sym,*) 'Rotation matrix of Wannier functions'
         WRITE(iun_sym,*) n_wannier
         DO isym=1, nsym2
            IF (all(abs(rotmat(:,:,isym)) < 1e-10)) CYCLE
            ncount = count(abs(rotmat(:,:,isym)) >= 1e-10)
            WRITE(iun_sym, *) isym, ncount
            DO m=1, n_wannier
               DO n=1, n_wannier
                  IF (abs(rotmat(m,n,isym)) < 1e-10) CYCLE
                  WRITE(iun_sym, '(2i5,2f22.15)') m, n, real(rotmat(m,n,isym)), aimag(rotmat(m,n,isym))
               END DO
            END DO
         END DO
         CLOSE(iun_sym)
      END IF
   END SUBROUTINE
   !
   SUBROUTINE get_representation_matrix(repmat)
      USE klist,           ONLY : nkstot, xk, ngk, igk_k
      USE wavefunctions,   ONLY : evc
      USE io_files,        ONLY : nwordwfc, iunwfc
      USE wvfct,           ONLY : nbnd, npwx, et
      USE uspp,            ONLY : nkb, vkb, okvan
      USE becmod,          ONLY : bec_type, becp, calbec, &
                                  allocate_bec_type, deallocate_bec_type
      USE cell_base,       ONLY : at
      USE noncollin_module,ONLY : noncolin, npol
      USE mp,              ONLY : mp_sum
      USE mp_pools,        ONLY : intra_pool_comm
      !
      COMPLEX(DP), INTENT(OUT) :: repmat(nbnd, nbnd, nsym2, nkstot)
      INTEGER                  :: i, ik, isym, m, n, npw
      REAL(DP)                 :: k(3), sk(3), kdiff(3)
      COMPLEX(DP), ALLOCATABLE :: spsi(:,:), gpsi(:,:)
      !
      repmat = 0
      !
      ALLOCATE(xkc(3,nkstot))
      xkc(:,1:nkstot)=xk(:,1:nkstot)
      CALL cryst_to_cart(nkstot,xkc,at,-1)
      !
      IF (okvan) CALL allocate_bec_type(nkb, nbnd, becp)
      !
      ALLOCATE (spsi(npwx*npol,nbnd), gpsi(npwx*npol,nbnd))
      !
      DO ik=1, nkstot
         k = xkc(:,ik)
         npw = ngk(ik)
         CALL davcio (evc, 2*nwordwfc, iunwfc, ik, -1 )
         IF (okvan) THEN
            CALL init_us_2(npw, igk_k(1,ik), xk(1,ik), vkb)
            CALL calbec(npw, vkb, evc, becp)
            CALL s_psi(npwx, npw, nbnd, evc, spsi)
         ELSE
            spsi = evc
         END IF
         DO isym=1, nsym2
            ! check k = s.k + G(kdiff)
            sk = matmul(s2(:,:,isym), k)
            if (t_rev2(isym) == 1) sk = -sk
            kdiff = k - sk
            IF (any(abs(kdiff - nint(kdiff)) > 1e-5)) CYCLE
            !
            CALL rotate_evc(isym, ik, ik, kdiff, evc, gpsi)
            !
            DO m=1, nbnd
               IF (excluded_band(m)) CYCLE
               DO n=1, nbnd
                 IF (excluded_band(n)) CYCLE
                 IF (abs(et(m,ik) - et(n,ik)) < 1e-5) THEN
                    IF (noncolin) THEN
                       repmat(m,n,isym,ik) = zdotc(npw, spsi(1,m), 1, gpsi(1,n), 1) &
                                           + zdotc(npw, spsi(npwx+1,m), 1, gpsi(npwx+1,n), 1)
                    ELSE
                       repmat(m,n,isym,ik) = zdotc(npw, spsi(1,m), 1, gpsi(1,n), 1)
                    END IF
                 END IF
               END DO
            END DO
         END DO
      END DO
      !
      CALL mp_sum(repmat, intra_pool_comm)
      !
      IF (okvan) CALL deallocate_bec_type(becp)
      !
   END SUBROUTINE
   !
   SUBROUTINE get_rotation_matrix(rotmat)
      !
      !  rotmat(m,n) = <g_m| S^-1 |g_n>
      !
      USE cell_base,       ONLY : at, bg
      USE constants,       ONLY : tpi
      USE wannier,         ONLY : n_wannier, l_w, mr_w, xaxis, zaxis, center_w, &
                                  spin_eig, spin_qaxis
      USE symm_base,       ONLY : d1, d2, d3, nsym
      !
      COMPLEX(DP), INTENT(OUT) :: rotmat(n_wannier, n_wannier, nsym2)
      !
      REAL(DP), parameter :: p12(3,12)=reshape(                            &
         (/0d0, 0d0, 1.00000000000000d0,                                   &
           0.894427190999916d0, 0d0, 0.447213595499958d0,                  &
           0.276393202250021d0, 0.850650808352040d0, 0.447213595499958d0,  &
          -0.723606797749979d0, 0.525731112119134d0, 0.447213595499958d0,  &
          -0.723606797749979d0, -0.525731112119134d0, 0.447213595499958d0, &
           0.276393202250021d0, -0.850650808352040d0, 0.447213595499958d0, &
           0.723606797749979d0, 0.525731112119134d0, -0.447213595499958d0, &
          -0.276393202250021d0, 0.850650808352040d0, -0.447213595499958d0, &
          -0.894427190999916d0, 0d0, -0.447213595499958d0,                 &
          -0.276393202250021d0, -0.850650808352040d0, -0.447213595499958d0,&
           0.723606797749979d0, -0.525731112119134d0, -0.447213595499958d0,&
           0d0, 0d0, -1.00000000000000d0/),(/3,12/))
      REAL(DP), parameter :: p20(3,20)=reshape(                            &
         (/0.525731112119134d0, 0.381966011250105d0, 0.850650808352040d0,  &
          -0.200811415886227d0, 0.618033988749895d0, 0.850650808352040d0,  &
          -0.649839392465813d0, 0d0, 0.850650808352040d0,                  &
          -0.200811415886227d0, -0.618033988749895d0, 0.850650808352040d0, &
           0.525731112119134d0, -0.381966011250105d0, 0.850650808352040d0, &
           0.850650808352040d0, 0.618033988749895d0, 0.200811415886227d0,  &
          -0.324919696232906d0, 1.00000000000000d0, 0.200811415886227d0,   &
          -1.05146222423827d0, 0d0, 0.200811415886227d0,                   &
         -0.324919696232906d0, -1.00000000000000d0, 0.200811415886227d0,   &
          0.850650808352040d0, -0.618033988749895d0, 0.200811415886227d0,  &
          0.324919696232906d0, 1.00000000000000d0, -0.200811415886227d0,   &
         -0.850650808352040d0, 0.618033988749895d0, -0.200811415886227d0,  &
         -0.850650808352040d0, -0.618033988749895d0, -0.200811415886227d0, &
          0.324919696232906d0, -1.00000000000000d0, -0.200811415886227d0,  &
          1.05146222423827d0, 0d0, -0.200811415886227d0,                   &
          0.200811415886227d0, 0.618033988749895d0, -0.850650808352040d0,  &
         -0.525731112119134d0, 0.381966011250105d0, -0.850650808352040d0,  &
         -0.525731112119134d0, -0.381966011250105d0, -0.850650808352040d0, &
          0.200811415886227d0, -0.618033988749895d0, -0.850650808352040d0, &
         0.649839392465813d0, 0d0, -0.850650808352040d0/),(/3,20/))
      REAL(DP), parameter :: pwg(2)=(/2.976190476190479d-2,3.214285714285711d-2/)
      !
      INTEGER               :: ip, jp, isym, iw, jw, np
      REAL(DP)              :: v1(3), v2(3), v3(3), v4(3), err, srt(3,3), tvec(3,96)
      REAL(DP)              :: dvec(3,32), dvec_in(3,32), dwgt(32), dylm1(32), dylm2(32)
      COMPLEX(DP)           :: spin1(2), spin2(2), u_spin(2,2)
      INTEGER, ALLOCATABLE  :: ip2iw(:), iw2ip(:), ips2p(:,:)
      REAL(DP), ALLOCATABLE :: vaxis(:,:,:)
      logical, ALLOCATABLE  :: lfound(:)
      COMPLEX(DP), ALLOCATABLE :: check_mat(:,:)
      INTEGER               :: l, m1, m2
      REAL(DP)              :: mat
      TYPE symmetrization_tensor
          REAL(DP), POINTER :: d(:,:,:)
      END TYPE symmetrization_tensor
      TYPE(symmetrization_tensor) :: D(0:3)
      !
      tvec=matmul(at(:,:),ft2(:,1:nsym2))
      !
      ! set dvec and dwgt for integration of spherical harmonics
      dvec(:,1:12) = p12
      dvec(:,13:32) = p20
      DO ip=1,32
         dvec(:,ip)=dvec(:,ip)/sqrt(sum(dvec(:,ip)**2))
      END DO
      dwgt(1:12)=pwg(1)
      dwgt(13:32)=pwg(2)
      !
      !Conversion table between Wannier and position indexes.
      allocate(iw2ip(n_wannier),ip2iw(n_wannier))
      np=0
      do iw=1,n_wannier
         v1=center_w(:,iw)
         jp=0
         do ip=1,np
            if(sum(abs(v1-center_w(:,ip2iw(ip)))).lt.1d-2) then
               jp=ip
               exit
            end if
         end do
         if(jp.eq.0) then
            np=np+1
            iw2ip(iw)=np
            ip2iw(np)=iw
         else
            iw2ip(iw)=jp
         end if
      end do
      !
      allocate(ips2p(np,nsym2),lfound(np))
      ips2p=-999 ! < 0
      do isym=1,nsym2
         lfound=.false.
         do ip=1,np
            v1=center_w(:,ip2iw(ip))
            v2=matmul(v1+tvec(:,isym), sr2(:,:,isym))
            do jp=1,np
               if(lfound(jp)) cycle
               v3=center_w(:,ip2iw(jp))
               v4=matmul(v3-v2,bg)
               if(sum(abs(dble(nint(v4))-v4)).lt.1d-2) then
                  lfound(jp)=.true.
                  ips2p(ip,isym)=jp
                  exit !Sym.op.(isym) moves position(ips2p(ip,isym)) to position(ip) + T, where
               end if                                       !T is given by vps2t(:,ip,isym).
            end do
            if(ips2p(ip,isym).le.0) then
               write(stdout,"(a,3f18.10,a,3f18.10,a)")"  Could not find ",v2,"(",matmul(v2,bg),")"
               write(stdout,"(a,3f18.10,a,3f18.10,a)")"  coming from    ",v1,"(",matmul(v1,bg),")"
               write(stdout,"(a,i5,a               )")"  of Wannier site",ip,"."
               call errore("compute_mmn_sym", "Error: missing Wannier sites, see the output.", 1)
            end if
         end do
      end do
      !
      allocate( vaxis(3,3,n_wannier) )
      rotmat=0.0d0
      do iw=1,n_wannier
         call set_u_matrix (xaxis(:,iw),zaxis(:,iw),vaxis(:,:,iw))
      end do
      do isym=1,nsym2
         srt = transpose(sr2(:,:,isym))
         CALL find_u(srt, u_spin)
         !IF (t_rev2(isym) == 1) u_spin = matmul(t_rev_spin, conjg(u_spin))
         do iw=1,n_wannier
            ip=iw2ip(iw)
            jp=ips2p(ip,isym)
            !
            dvec_in = matmul(vaxis(:,:,iw),dvec)
            CALL ylm_wannier(dylm1,l_w(iw),mr_w(iw),dvec_in,32)
            !
            do jw=1,n_wannier
               if(iw2ip(jw).ne.jp) cycle
               !
               dvec_in = matmul( vaxis(:,:,jw), matmul( srt, dvec ) )
               CALL ylm_wannier(dylm2,l_w(jw),mr_w(jw),dvec_in,32)
               !
               ! <Y(iw) | S(isym)^-1 Y(jw)>
               rotmat(iw,jw,isym)=sum(dylm1(:)*dylm2(:)*dwgt)*2d0*tpi
               IF (noncolin) THEN
                  spin1(:) = spinor( spin_qaxis(:,iw), spin_eig(iw) )
                  spin2(:) = spinor( spin_qaxis(:,jw), spin_eig(jw) )
                  IF (t_rev2(isym) == 1) THEN
                     ! t_rev_spin^-1 = tr(t_rev_spin)
                     spin2(:) = matmul(transpose(t_rev_spin), conjg(spin2))
                  END IF
                  spin2(:) = matmul(transpose(conjg(u_spin)), spin2)
                  rotmat(iw,jw,isym)=rotmat(iw,jw,isym) * dot_product(spin1,spin2)
               END IF
            end do
         end do
      end do
      deallocate(vaxis)
      deallocate(ips2p, lfound, iw2ip, ip2iw)
      allocate(check_mat(n_wannier, n_wannier))
      do isym=1,nsym2
         if(t_rev2(isym) == 0) then
            ! rotmat(:,:,isym) is unitary
            check_mat = matmul(rotmat(:,:,isym), transpose(conjg(rotmat(:,:,isym))))
         else
            ! rotmat(:,:,isym) is anti-unitary
            check_mat = (0.d0, 1.d0) * rotmat(:,:,isym)
            check_mat = matmul(check_mat(:,:), transpose(conjg(check_mat(:,:))))
         end if
         do iw=1,n_wannier
            do jw=1, n_wannier
               if( (iw == jw .and. abs(check_mat(iw,jw) - 1) > 1d-3) .or. &
                   (iw /= jw .and. abs(check_mat(iw,jw)) > 1d-3) ) then
                  write(stdout,"(a,i5,a,i5,a)") "compute_mmn_ibz: Symmetry operator (", isym, &
                          ") could not transform Wannier function (", iw, ")."
                  write(stdout,"(a,f15.7,a  )") "compute_mmn_ibz: The error is ", check_mat(iw,jw) , "."
                  write(stdout,*) "rotmat(:,:,isym)"
                  write(stdout,*) rotmat(:,:,isym)
                  write(stdout,*) "check_mat"
                  write(stdout,*) check_mat
                  call errore("compute_mmn_ibz", "Error: missing Wannier functions, see the output.", 1)
               end if
            end do
         end do
      end do
      deallocate(check_mat)
      !
      ! check d_matrix and this calculation
      !
      !write(stdout, *) '  checking d_matrix... \n'
      !CALL d_matrix(d1, d2, d3)
      !D(1)%d => d1 ! d1(3,3,48)
      !D(2)%d => d2 ! d2(5,5,48)
      !D(3)%d => d3 ! d3(7,7,48)
      !do isym=1, nsym
      !   srt = transpose(sr2(:,:,isym))
      !   l = 1
      !   do l=1, 3
      !      do m1 = 1, 2*l+1
      !         dvec_in = dvec
      !         CALL ylm_wannier(dylm1,l,m1,dvec_in,32)
      !         do m2 = 1, 2*l+1
      !            dvec_in = matmul( srt, dvec )
      !            CALL ylm_wannier(dylm2,l,m2,dvec_in,32)
      !            mat = sum(dylm1(:)*dylm2(:)*dwgt)*2d0*tpi  ! rotmat
      !            if(abs(mat - D(l)%d(m1,m2,isym)) > 1e-8) write(stdout, '(2i5, 2f15.7)') m1, m2, mat, D(l)%d(m1,m2,isym)
      !         end do
      !      end do
      !      do m1 = 1, 2*l+1
      !         write(stdout, *) dot_product(D(l)%d(m1,1:2*l+1,isym), D(l)%d(m1,1:2*l+1,isym))
      !      end do
      !   end do
      !end do
   END SUBROUTINE get_rotation_matrix
   !
   SUBROUTINE rotate_evc(isym, ik1, ik2, kdiff, psi, gpsi)
      !-----------------------------------------------------------------------
      ! g psi_k = e^{ik1.rS} u_k(rS) = e^{iSk1.r} u_k(rS)
      !         = e^{ik2.r} [ e^{-iGr} u_k(rS) ]
      ! k2 = s.k1 + G
      ! S=s(:,:,isym)   G=kdiff
      ! gvector order is k(:,ik1) for input and k(:,ik2) for output
      !
      ! with T  rotation + T (apply rotation and then apply T)
      ! k2 = -s.k1 + G
      ! g psi_k = [ e^{iSk1.r} u_k(rS) ]^*
      !         = e^{ik2.r} e^{-iGr} [ u_k(rS) ]^*
      !
      USE wvfct,           ONLY : nbnd, npwx
      USE wavefunctions,   ONLY : evc, psic, psic_nc
      USE fft_base,        ONLY : dffts, dfftp
      USE fft_interfaces,  ONLY : fwfft, invfft
      USE cell_base,       ONLY : bg
      USE constants,       ONLY : tpi
      USE gvect,           ONLY : g, ngm
      USE klist,           ONLY : igk_k, ngk
      USE mp,              ONLY : mp_sum
      USE mp_pools,        ONLY : intra_pool_comm
      USE fft_interfaces,  ONLY : invfft
      USE scatter_mod,     ONLY : gather_grid, scatter_grid
      IMPLICIT NONE
      !
      INTEGER, INTENT(IN):: isym, ik1, ik2
      REAL(DP), INTENT(IN):: kdiff(3)
      COMPLEX(DP), INTENT(IN):: psi(npwx*npol,nbnd)
      COMPLEX(DP), INTENT(OUT):: gpsi(npwx*npol,nbnd)
      !
      INTEGER:: ig, igk_local, igk_global, npw1, npw2, n, nxxs, ipol, istart, isym0
      REAL(DP)                 :: kdiff_cart(3), srt(3,3)
      REAL(DP)                 :: phase_arg
      COMPLEX(DP)              :: phase_factor, u_spin(2,2), u_spin2(2,2)
      COMPLEX(DP), ALLOCATABLE :: phase(:), gpsi_tmp(:,:)
      COMPLEX(DP), ALLOCATABLE :: psic_all(:), temppsic_all(:)
      !
      nxxs = dffts%nr1x *dffts%nr2x *dffts%nr3x
      ALLOCATE( psic_all(nxxs), temppsic_all(nxxs), gpsi_tmp(npwx,2) )
      ALLOCATE( phase(dffts%nnr) )
      !
      ! for spin space rotation (only used for noncollinear case)
      !
      srt = transpose(sr2(:,:,isym))
      CALL find_u(srt, u_spin)
      !
      ! kdiff = g(:,igk_global)
      !
      kdiff_cart = kdiff
      CALL cryst_to_cart(1, kdiff_cart, bg, 1)
      igk_local = 0
      DO ig = 1, ngm
         IF ( all (abs(kdiff_cart - g(:,ig)) < 1d-5) ) THEN
            igk_local = ig
            exit
         END IF
      END DO
      igk_global = igk_local
      CALL mp_sum(igk_global, intra_pool_comm)
      !
      ! phase = e^{iGr}
      !
      IF (igk_global > 0) THEN
         phase(:) = (0.d0, 0.d0)
         IF (igk_local > 0) phase( dffts%nl(igk_local) ) = (1.d0, 0.d0)
         CALL invfft ('Wave', phase, dffts)
      END IF
      !
      gpsi = 0
      !
      npw1 = ngk(ik1)
      npw2 = ngk(ik2)
      DO n=1, nbnd
         IF (excluded_band(n)) CYCLE
         !
         ! real space rotation
         !
         gpsi_tmp = 0
         DO ipol=1,npol
            istart = npwx*(ipol-1)
            psic(:) = (0.d0, 0.d0)
            psic(dffts%nl (igk_k (1:npw1,ik1) ) ) = psi (istart+1:istart+npw1, n)
            !
            IF (igk_global > 0 .or. isym > 1) THEN
               CALL invfft ('Wave', psic, dffts)
               IF (isym > 1) THEN
#if defined(__MPI)
                  ! gather among all the CPUs
                  CALL gather_grid(dffts, psic, temppsic_all)
                  ! apply rotation
                  psic_all(1:nxxs) = temppsic_all(rir(1:nxxs,isym))
                  ! scatter back a piece to each CPU
                  CALL scatter_grid(dffts, psic_all, psic)
#else
                  psic(1:nxxs) = psic(rir(1:nxxs,isym))
#endif
               ENDIF
               IF(t_rev2(isym) == 1) psic = conjg(psic)
               ! apply phase e^{-iGr}
               IF(igk_global > 0) psic(1:dffts%nnr) = psic(1:dffts%nnr) * conjg(phase(1:dffts%nnr))

               CALL fwfft ('Wave', psic, dffts)
            END IF
            !
            gpsi_tmp(1:npw2,ipol)  = psic(dffts%nl (igk_k(1:npw2,ik2) ) )
         END DO
         !
         ! spin space rotation
         !
         DO ipol=1,npol
            istart = npwx*(ipol-1)
            IF (noncolin) THEN
               u_spin2 = u_spin
               IF (t_rev2(isym) == 1) u_spin2 = matmul(t_rev_spin, conjg(u_spin))
               gpsi(istart+1:istart+npw2,n) = matmul(gpsi_tmp(1:npw2,:), u_spin2(ipol,:))
            ELSE
               gpsi(istart+1:istart+npw2,n) = gpsi_tmp(1:npw2,ipol)
            END IF
         END DO
      END DO
      !
      phase_arg = -tpi * dot_product(xkc(:,ik1), ft2(:,isym))
      IF (t_rev2(isym) == 1) phase_arg = -phase_arg
      phase_factor = CMPLX(COS(phase_arg), SIN(phase_arg), KIND=DP)
      gpsi = gpsi * phase_factor
      !
      DEALLOCATE( phase, psic_all, temppsic_all, gpsi_tmp )
   END SUBROUTINE rotate_evc
   !
   SUBROUTINE kpb_search(ik, ib, ikp, isym, kdiff, skp)
      ! input: ik, ib
      ! output: ikp, isym, kdiff, skp = s.xkc
      ! xkc(:,ik) + xbvec(:,ib) = s(:,:,isym) . xkc(:,ikp) + kdiff
      ! if with T
      ! xkc(:,ik) + xbvec(:,ib) = - s(:,:,isym) . xkc(:,ikp) + kdiff
      ! 
      USE kinds,           ONLY : DP
      USE klist,           ONLY : nkstot
      USE wannier,         ONLY : xbvec
      USE io_global,       ONLY : stdout
      IMPLICIT NONE
      INTEGER, INTENT(in):: ik, ib
      INTEGER, INTENT(out):: ikp, isym
      REAL(DP), INTENT(out):: kdiff(3), skp(3)
      !
      REAL(DP):: k(3), kb(3)
      INTEGER:: i

      k = xkc(:,ik)
      kb = xkc(:,ik) + xbvec(:,ib)
      do isym = 1, nsym2
        do ikp = 1, nkstot
          skp = matmul(s2(:,:,isym), xkc(:,ikp))
          IF (t_rev2(isym) == 1) skp = -skp
          kdiff = kb - skp
          if ( all( abs(nint(kdiff) - kdiff) < 1d-5 ) ) then
            return
          end if
        end do
      end do
      WRITE(stdout, *) "ikp, isym not found for kb = ", kb
      CALL errore('kpb_search', 'ikp, isym not found', 1)
   END SUBROUTINE
   !
   SUBROUTINE init_qb_so(qb, qq_so)
      ! TODO: Use this also in compute_mmn
      USE uspp_param,      ONLY : upf, nh, lmaxq, nhm
      !USE ions_base,       ONLY : nat, ntyp, ityp, tau
      USE cell_base,       ONLY : omega, tpiba
      USE ions_base,       ONLY : ntyp => nsp
      USE noncollin_module,ONLY : lspinorb
      USE wannier,         ONLY : nnb
      !
      COMPLEX(DP), INTENT(out) :: qb(nhm, nhm, ntyp, nnb), qq_so(nhm, nhm, 4, ntyp, nnb)
      !
      INTEGER :: ih, jh, nt, ib
      REAL(DP), ALLOCATABLE    :: qg(:), ylm(:,:)
      COMPLEX(DP), ALLOCATABLE :: qgm(:), qq_so_tmp(:,:,:,:)
      !
      ALLOCATE( ylm(nnb, lmaxq*lmaxq), qg(nnb), qgm(nnb), qq_so_tmp(nhm, nhm, 4, ntyp) )
      !
      DO ib=1, nnb
         qg(ib) = dot_product(bvec(:,ib), bvec(:,ib))
      END DO
      CALL ylmr2(lmaxq*lmaxq, nnb, bvec, qg, ylm)
      qg = sqrt(qg) * tpiba
      !
      DO nt =1, ntyp
         IF( .not. upf(nt)%tvanp ) CYCLE
         DO ih = 1, nh(nt)
            DO jh = 1, nh(nt)
               CALL qvan2(nnb, ih, jh, nt, qg, qgm, ylm)
               qb(ih, jh, nt, :) = omega * qgm(:)
            END DO
         END DO
      END DO
      !
      IF (lspinorb) THEN
         qq_so = (0.d0, 0.d0)
         DO ib=1, nnb
            qq_so_tmp = 0
            CALL transform_qq_so(qb(:,:,:,ib), qq_so_tmp)
            qq_so(:,:,:,:,ib) = qq_so_tmp
         END DO
      END IF
      !
      DEALLOCATE( qg, qgm, ylm, qq_so_tmp )
      !
   END SUBROUTINE
   !
   SUBROUTINE rotate_becp(isym, sgn_sym, xk0, xk, becp1, becp2)
      !
      ! based on becp_rotate_k in us_exx.f90
      !
      USE kinds,           ONLY : DP
      USE cell_base,       ONLY : at, bg
      USE ions_base,       ONLY : tau, nat, ityp
      USE symm_base,       ONLY : irt, d1, d2, d3, nsym, invs
      USE uspp,            ONLY : nkb, ofsbeta, nhtolm, nhtol
      USE uspp_param,      ONLY : nh, upf
      !
      IMPLICIT NONE
      !
      INTEGER, INTENT(IN)            :: isym, sgn_sym
      REAL(DP), INTENT(IN)           :: xk0(3), xk(3)
      TYPE (bec_type), INTENT(IN)    :: becp1
      TYPE (bec_type), INTENT(INOUT) :: becp2
      !
      INTEGER     :: ia, nt, ma, ih, m_o, lm_i, l_i, m_i, ikb, oh, okb, isym0, isym_inv
      REAL(DP)    :: xau(3,nat), rau(3,nat), tau_phase
      COMPLEX(DP) :: tau_fact
      COMPLEX(DP) :: u_spin(2,2)
      !
      REAL(DP), TARGET :: d0(1,1,48)
      TYPE symmetrization_tensor
          REAL(DP), POINTER :: d(:,:,:)
      END TYPE symmetrization_tensor
      TYPE(symmetrization_tensor) :: D(0:3)
      !
      !
      IF ( isym == 1 ) THEN
         IF (sgn_sym > 0) THEN
            IF (noncolin) THEN
               becp2%nc = becp1%nc
            ELSE
               becp2%k = becp1%k
            END IF
         ELSE
            IF (noncolin) THEN
               becp2%nc = CONJG(becp1%nc)
            ELSE
               becp2%k = CONJG(becp1%k)
            END IF
         ENDIF
         RETURN
      ENDIF
      !
      CALL d_matrix(d1,d2,d3)
      d0(1,1,:) = 1._dp
      D(0)%d => d0 ! d0(1,1,48)
      D(1)%d => d1 ! d1(3,3,48)
      D(2)%d => d2 ! d2(5,5,48)
      D(3)%d => d3 ! d3(7,7,48)
      ! set isym0 for d0~d3 and irt
      IF (isym > nsym) THEN
        isym0 = isym - nsym
      ELSE
        isym0 = isym
      END IF
      !
      IF (ABS(sgn_sym) /= 1) CALL errore( "becp_rotate", "sign must be +1 or -1", 1 )
      !
      xau = tau
      CALL cryst_to_cart( nat, xau, bg, -1 )
      !
      DO ia = 1,nat
         rau(:,ia) = matmul(xau(:,ia), s2(:,:,isym)) - ft2(:,isym)
      ENDDO
      !
      CALL cryst_to_cart( nat, rau, at, +1 )
      !
      IF (noncolin) THEN
         becp2%nc = 0._dp
         call find_u( transpose(sr2(:,:,isym)), u_spin )
         IF (t_rev2(isym) == 1) u_spin = matmul(t_rev_spin, conjg(u_spin))
      ELSE
         becp2%k = 0._dp
      END IF
      DO ia = 1,nat
         nt = ityp(ia)
         ma = irt(isym0,ia)
         tau_phase = -tpi*( sgn_sym*SUM((tau(:,ma)-rau(:,ia))*xk0) )

         tau_fact = CMPLX(COS(tau_phase), SIN(tau_phase), KIND=DP)
         !
         DO ih = 1, nh(nt)
            !
            lm_i  = nhtolm(ih,nt)
            l_i   = nhtol(ih,nt)
            m_i   = lm_i - l_i**2
            ikb = ofsbeta(ma) + ih
            !
            DO m_o = 1, 2*l_i +1
               oh = ih - m_i + m_o
               okb = ofsbeta(ia) + oh
               IF (noncolin) THEN
                  IF (sgn_sym > 0) THEN
                     becp2%nc(okb, :, :) = becp2%nc(okb, :, :) &
                       + matmul(u_spin, D(l_i)%d(m_i,m_o, isym0) * tau_fact*becp1%nc(ikb, :, :))
                  ELSE
                     becp2%nc(okb, :, :) = becp2%nc(okb, :, :) &
                       + matmul(u_spin, D(l_i)%d(m_i,m_o, isym0) * tau_fact*CONJG(becp1%nc(ikb, :, :)))
                  ENDIF
               ELSE
                  IF (sgn_sym > 0) THEN
                     becp2%k(okb, :) = becp2%k(okb, :) &
                       + D(l_i)%d(m_i,m_o, isym0) * tau_fact*becp1%k(ikb, :)
                  ELSE
                     becp2%k(okb, :) = becp2%k(okb, :) &
                       + D(l_i)%d(m_i,m_o, isym0) * tau_fact*becp1%k(ikb, :)
                  ENDIF
               END IF
            ENDDO ! m_o
         ENDDO ! ih
      ENDDO ! nat
   END SUBROUTINE
   !
   FUNCTION spinor(r, eig)
      ! Compute a spin-1/2 state polarized along r.
      ! Return spin up state if eig > 0, spin down state otherwise.
      COMPLEX(DP):: spinor(2), ci
      INTEGER:: eig
      REAL(DP):: r(3), theta, phi
      ci = (0.d0, 1.d0)
      theta = acos(r(3)/sqrt(r(1)**2+r(2)**2+r(3)**2))
      phi = atan2(r(2), r(1))
      if(eig > 0) then
         spinor(1) = cos(theta/2)
         spinor(2) = exp( ci * phi ) * sin(theta/2)
      else
         spinor(1) = -exp( -ci * phi ) * sin(theta/2)
         spinor(2) = cos(theta/2)
      end if
      RETURN
   END FUNCTION
   !
   SUBROUTINE pw2wan_set_symm_with_time_reversal(nr1, nr2, nr3, nr1x, nr2x, nr3x)
      ! based on exx_set_symm in exx_base.f90
      !
      IMPLICIT NONE
      !
      INTEGER, INTENT(IN) :: nr1, nr2, nr3, nr1x, nr2x, nr3x 
      !
      ! ... local variables
      !
      INTEGER :: ikq, isym, i,j,k, ri,rj,rk, ir, nxxs
      INTEGER, allocatable :: ftau(:,:), s_scaled(:,:,:)
      !
      nxxs = nr1x*nr2x*nr3x
      !
      ALLOCATE( rir(nxxs,nsym2) )
      !
      rir = 0
      ALLOCATE ( ftau(3,nsym2), s_scaled(3,3,nsym2) )
      CALL scale_sym_ops (nsym2, s2, ft2, nr1, nr2, nr3, s_scaled, ftau)

      DO isym = 1, nsym2
         DO k = 1, nr3
            DO j = 1, nr2
               DO i = 1, nr1
                  CALL rotate_grid_point( s_scaled(1,1,isym), ftau(1,isym), &
                       i, j, k, nr1, nr2, nr3, ri, rj, rk )
                  ir = i + (j-1)*nr1x + (k-1)*nr1x*nr2x
                  rir(ir,isym) = ri + (rj-1)*nr1x + (rk-1)*nr1x*nr2x
               ENDDO
            ENDDO
         ENDDO
      ENDDO
      !
      DEALLOCATE ( s_scaled, ftau )
      !
   END SUBROUTINE pw2wan_set_symm_with_time_reversal
   !
END SUBROUTINE compute_mmn_ibz

!-----------------------------------------------------------------------
SUBROUTINE compute_spin
   !-----------------------------------------------------------------------
   !
   USE io_global,  ONLY : stdout, ionode
   USE kinds,           ONLY: DP
   USE wvfct,           ONLY : nbnd, npwx
   USE control_flags,   ONLY : gamma_only
   USE wavefunctions, ONLY : evc, psic, psic_nc
   USE fft_base,        ONLY : dffts, dfftp
   USE fft_interfaces,  ONLY : fwfft, invfft
   USE klist,           ONLY : nkstot, xk, ngk, igk_k
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE gvect,           ONLY : g, ngm, gstart
   USE cell_base,       ONLY : alat, at, bg
   USE ions_base,       ONLY : nat, ntyp => nsp, ityp, tau
   USE constants,       ONLY : tpi
   USE uspp,            ONLY : nkb, vkb
   USE uspp_param,      ONLY : upf, nh, lmaxq
   USE becmod,          ONLY : bec_type, becp, calbec, &
                               allocate_bec_type, deallocate_bec_type
   USE mp_pools,        ONLY : intra_pool_comm
   USE mp,              ONLY : mp_sum
   USE noncollin_module,ONLY : noncolin, npol
   USE gvecw,           ONLY : gcutw
   USE wannier
   ! begin change Lopez, Thonhauser, Souza
   USE mp,              ONLY : mp_barrier
   USE scf,             ONLY : vrs, vltot, v, kedtau
   USE gvecs,           ONLY : doublegrid
   USE lsda_mod,        ONLY : nspin
   USE constants,       ONLY : rytoev

   USE uspp_param,      ONLY : upf, nh, nhm
   USE uspp,            ONLY: qq_nt, nhtol,nhtoj, indv
   USE upf_spinorb,     ONLY : fcoef
   USE uspp_init,       ONLY : init_us_2

   IMPLICIT NONE
   !
   INTEGER, EXTERNAL :: find_free_unit
   !
   complex(DP), parameter :: cmplx_i=(0.0_DP,1.0_DP)
   !
   INTEGER :: npw, mmn_tot, ik, ikp, ipol, ib, i, m, n
   INTEGER :: ikb, jkb, ih, jh, na, nt, ijkb0, ind, nbt
   INTEGER :: ikevc, ikpevcq, s, counter
   COMPLEX(DP)              :: mmn, zdotc, phase1
   real(DP)                 :: arg, g_(3)
   CHARACTER (len=9)        :: cdate,ctime
   CHARACTER (len=header_len) :: header
   LOGICAL                  :: any_uspp
   INTEGER                  :: nn,inn,loop,loop2
   LOGICAL                  :: nn_found
   INTEGER                  :: istart,iend
   COMPLEX(DP)              :: sigma_x,sigma_y,sigma_z,cdum1,cdum2
   complex(DP), allocatable :: spn(:,:), spn_aug(:,:)

   integer  :: np, is1, is2, kh, kkb
   complex(dp) :: sigma_x_aug, sigma_y_aug, sigma_z_aug
   COMPLEX(DP), ALLOCATABLE :: be_n(:,:), be_m(:,:)


   any_uspp = any(upf(1:ntyp)%tvanp)

   if (any_uspp) then
      CALL allocate_bec_type ( nkb, nbnd, becp )
      ALLOCATE(be_n(nhm,2))
      ALLOCATE(be_m(nhm,2))
   endif


   if (write_spn) allocate(spn(3,(num_bands*(num_bands+1))/2))
   if (write_spn) allocate(spn_aug(3,(num_bands*(num_bands+1))/2))
   spn_aug = (0.0d0, 0.0d0)
!ivo
! not sure this is really needed
   if((write_spn.or.write_uhu.or.write_uIu).and.wan_mode=='library')&
        call errore('pw2wannier90',&
        'write_spn, write_uhu, and write_uIu not meant to work library mode',1)
!endivo

   IF(write_spn.and.noncolin) THEN
      IF (ionode) then
         iun_spn = find_free_unit()
         CALL date_and_tim( cdate, ctime )
         header='Created on '//cdate//' at '//ctime
         if(spn_formatted) then
            OPEN (unit=iun_spn, file=trim(seedname)//".spn",form='formatted')
            WRITE (iun_spn,*) header !ivo
            WRITE (iun_spn,*) nbnd-nexband,iknum
         else
            OPEN (unit=iun_spn, file=trim(seedname)//".spn",form='unformatted')
            WRITE (iun_spn) header !ivo
            WRITE (iun_spn) nbnd-nexband,iknum
         endif
      ENDIF
   ENDIF
   !
   WRITE(stdout,'(a,i8)') ' iknum = ',iknum

   ind = 0
   DO ik=1,iknum
      WRITE (stdout,'(i8)') ik
      ikevc = ik + ikstart - 1
      CALL davcio (evc, 2*nwordwfc, iunwfc, ikevc, -1 )
      npw = ngk(ik)
      !
      !  USPP
      !
      IF(any_uspp) THEN
         CALL init_us_2 (npw, igk_k(1,ik), xk(1,ik), vkb)
         ! below we compute the product of beta functions with |psi>
         CALL calbec (npw, vkb, evc, becp)
      ENDIF


      IF(write_spn.and.noncolin) THEN
         counter=0
         DO m=1,nbnd
            if(excluded_band(m)) cycle !ivo
            DO n=1,m
               if(excluded_band(n)) cycle !ivo
               cdum1=zdotc(npw,evc(1,n),1,evc(npwx+1,m),1)
               call mp_sum(cdum1,intra_pool_comm)
               cdum2=zdotc(npw,evc(npwx+1,n),1,evc(1,m),1)
               call mp_sum(cdum2,intra_pool_comm)
               sigma_x=cdum1+cdum2
               sigma_y=cmplx_i*(cdum2-cdum1)
               sigma_z=zdotc(npw,evc(1,n),1,evc(1,m),1)&
                    -zdotc(npw,evc(npwx+1,n),1,evc(npwx+1,m),1)
               call mp_sum(sigma_z,intra_pool_comm)
               counter=counter+1
               spn(1,counter)=sigma_x
               spn(2,counter)=sigma_y
               spn(3,counter)=sigma_z

               if (any_uspp) then
                 sigma_x_aug = (0.0d0, 0.0d0)
                 sigma_y_aug = (0.0d0, 0.0d0)
                 sigma_z_aug = (0.0d0, 0.0d0)
                 ijkb0 = 0

                 DO np = 1, ntyp
                    IF ( upf(np)%tvanp ) THEN
                       DO na = 1, nat
                          IF (ityp(na)==np) THEN
                             be_m = 0.d0
                             be_n = 0.d0
                             DO ih = 1, nh(np)
                                ikb = ijkb0 + ih
                                IF (upf(np)%has_so) THEN
                                    DO kh = 1, nh(np)
                                       IF ((nhtol(kh,np)==nhtol(ih,np)).and. &
                                            (nhtoj(kh,np)==nhtoj(ih,np)).and.     &
                                            (indv(kh,np)==indv(ih,np))) THEN
                                          kkb=ijkb0 + kh
                                          DO is1=1,2
                                             DO is2=1,2
                                                be_n(ih,is1)=be_n(ih,is1)+  &
                                                     fcoef(ih,kh,is1,is2,np)*  &
                                                     becp%nc(kkb,is2,n)

                                                be_m(ih,is1)=be_m(ih,is1)+  &
                                                     fcoef(ih,kh,is1,is2,np)*  &
                                                     becp%nc(kkb,is2,m)
                                             ENDDO
                                          ENDDO
                                       ENDIF
                                    ENDDO
                                ELSE
                                   DO is1=1,2
                                      be_n(ih, is1) = becp%nc(ikb, is1, n)
                                      be_m(ih, is1) = becp%nc(ikb, is1, m)
                                   ENDDO
                                ENDIF
                             ENDDO
                                DO ih = 1, nh(np)
                                   DO jh = 1, nh(np)
                                      sigma_x_aug = sigma_x_aug &
                                        + qq_nt(ih,jh,np) * ( be_m(jh,2)*conjg(be_n(ih,1))+ be_m(jh,1)*conjg(be_n(ih,2)) )

                                      sigma_y_aug = sigma_y_aug &
                                      + qq_nt(ih,jh,np) * (  &
                                          be_m(jh,1) * conjg(be_n(ih,2)) &
                                          - be_m(jh,2) * conjg(be_n(ih,1)) &
                                        ) * (0.0d0, 1.0d0)

                                      sigma_z_aug = sigma_z_aug &
                                      + qq_nt(ih,jh,np) * ( be_m(jh,1)*conjg(be_n(ih,1)) - be_m(jh,2)*conjg(be_n(ih,2)) )
                                   ENDDO
                                ENDDO
                             ijkb0 = ijkb0 + nh(np)
                          ENDIF
                       ENDDO
                    ELSE
                       DO na = 1, nat
                          IF ( ityp(na) == np ) ijkb0 = ijkb0 + nh(np)
                       ENDDO
                    ENDIF
                 ENDDO
                 spn_aug(1, counter) = sigma_x_aug
                 spn_aug(2, counter) = sigma_y_aug
                 spn_aug(3, counter) = sigma_z_aug
               endif
            ENDDO
         ENDDO
         if(ionode) then ! root node for i/o
            if(spn_formatted) then ! slow formatted way
               counter=0
               do m=1,num_bands
                  do n=1,m
                     counter=counter+1
                     do s=1,3
                         write(iun_spn,'(2es26.16)') spn(s,counter) + spn_aug(s,counter)
                      enddo
                   enddo
                enddo
             else ! fast unformatted way
                write(iun_spn) ((spn(s,m) + spn_aug(s,m),s=1,3),m=1,((num_bands*(num_bands+1))/2))
             endif
          endif ! end of root activity


      ENDIF

   end DO

   IF (ionode .and. write_spn .and. noncolin) CLOSE (iun_spn)

   if(write_spn.and.noncolin) deallocate(spn, spn_aug)
   if (any_uspp) then
      deallocate(be_n, be_m)
      call deallocate_bec_type(becp)
   endif

   WRITE(stdout,*)
   WRITE(stdout,*) ' SPIN calculated'

   RETURN
END SUBROUTINE compute_spin

!-----------------------------------------------------------------------
SUBROUTINE compute_orb
   !-----------------------------------------------------------------------
   !
   USE io_global,  ONLY : stdout, ionode
   USE kinds,           ONLY: DP
   USE wvfct,           ONLY : nbnd, npwx, current_k
   USE control_flags,   ONLY : gamma_only
   USE wavefunctions, ONLY : evc, psic, psic_nc
   USE fft_base,        ONLY : dffts, dfftp
   USE fft_interfaces,  ONLY : fwfft, invfft
   USE klist,           ONLY : nkstot, xk, ngk, igk_k
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE gvect,           ONLY : g, ngm, gstart
   USE cell_base,       ONLY : tpiba2, alat, at, bg
   USE ions_base,       ONLY : nat, ntyp => nsp, ityp, tau
   USE constants,       ONLY : tpi
   USE uspp,            ONLY : nkb, vkb
   USE uspp_param,      ONLY : upf, nh, lmaxq
   USE becmod,          ONLY : bec_type, becp, calbec, &
                               allocate_bec_type, deallocate_bec_type
   USE mp_pools,        ONLY : intra_pool_comm
   USE mp,              ONLY : mp_sum
   USE noncollin_module,ONLY : noncolin, npol
   USE gvecw,           ONLY : gcutw
   USE wannier
   ! begin change Lopez, Thonhauser, Souza
   USE mp,              ONLY : mp_barrier
   USE scf,             ONLY : vrs, vltot, v, kedtau
   USE gvecs,           ONLY : doublegrid
   USE lsda_mod,        ONLY : lsda, nspin, isk, current_spin
   USE constants,       ONLY : rytoev
   USE uspp_init,            ONLY : init_us_2

   IMPLICIT NONE
   !
   INTEGER, EXTERNAL :: find_free_unit
   !
   complex(DP), parameter :: cmplx_i=(0.0_DP,1.0_DP)
   !
   INTEGER :: mmn_tot, ik, ikp, ipol, npw, i, m, n
   INTEGER :: ikb, jkb, ih, jh, na, nt, ijkb0, ind, nbt
   INTEGER :: ikevc, ikpevcq, s, counter
   COMPLEX(DP), ALLOCATABLE :: phase(:), aux(:), aux2(:), evcq(:,:), &
                               becp2(:,:), Mkb(:,:), aux_nc(:,:)
   real(DP), ALLOCATABLE    :: rbecp2(:,:)
   COMPLEX(DP), ALLOCATABLE :: qb(:,:,:,:), qgm(:)
   real(DP), ALLOCATABLE    :: qg(:), ylm(:,:)
   COMPLEX(DP)              :: mmn, zdotc, phase1
   real(DP)                 :: arg, g_(3)
   CHARACTER (len=9)        :: cdate,ctime
   CHARACTER (len=header_len) :: header
   LOGICAL                  :: any_uspp
   INTEGER                  :: nn,inn,loop,loop2
   LOGICAL                  :: nn_found
   INTEGER                  :: istart,iend
   ! begin change Lopez, Thonhauser, Souza
   COMPLEX(DP)              :: sigma_x,sigma_y,sigma_z,cdum1,cdum2
   integer                  :: npw_b1, npw_b2, i_b1, i_b2, ikp_b1, ikp_b2
!   integer, allocatable     :: igk_b1(:), igk_b2(:)
   complex(DP), allocatable :: evc_b1(:,:),evc_b2(:,:),evc_aux(:,:),H_evc(:,:)
   complex(DP), allocatable :: uHu(:,:),uIu(:,:)
   ! end change Lopez, Thonhauser, Souza
   INTEGER                  :: ibnd_n, ibnd_m

   any_uspp = any(upf(1:ntyp)%tvanp)

   IF(gamma_only) CALL errore('pw2wannier90',&
        'write_uHu and write_uIu not yet implemented for gamma_only case',1) !ivo
   IF(any_uspp) CALL errore('pw2wannier90',&
        'write_uHu and write_uIu not yet implemented with USP',1) !ivo

   ALLOCATE( phase(dffts%nnr) )
   ALLOCATE( evcq(npol*npwx,nbnd) )

   IF(noncolin) THEN
      ALLOCATE( aux_nc(npwx,npol) )
   ELSE
      ALLOCATE( aux(npwx) )
   ENDIF

!   IF (gamma_only) ALLOCATE(aux2(npwx))

   IF (wan_mode=='library') ALLOCATE(m_mat(num_bands,num_bands,nnb,iknum))

   if (write_uHu) allocate(uhu(num_bands,num_bands))
   if (write_uIu) allocate(uIu(num_bands,num_bands))


!ivo
! not sure this is really needed
   if((write_uhu.or.write_uIu).and.wan_mode=='library')&
        call errore('pw2wannier90',&
        'write_uhu, and write_uIu not meant to work library mode',1)
!endivo


   !
   !
   ! begin change Lopez, Thonhauser, Souza
   !
   !====================================================================
   !
   ! The following code was inserted by Timo Thonhauser, Ivo Souza, and
   ! Graham Lopez in order to calculate the matrix elements
   ! <u_n(q+b1)|H(q)|u_m(q+b2)> necessary for the Wannier interpolation
   ! of the orbital magnetization
   !
   !====================================================================
   !
   !
   !
   if(write_uHu.or.write_uIu) then !ivo
     !
     !
     !
!     allocate(igk_b1(npwx),igk_b2(npwx),evc_b1(npol*npwx,nbnd),&
     allocate(evc_b1(npol*npwx,nbnd),&
          evc_b2(npol*npwx,nbnd),&
          evc_aux(npol*npwx,nbnd))
     !
     if(write_uHu) then
        allocate(H_evc(npol*npwx,nbnd))
        write(stdout,*)
        write(stdout,*) ' -----------------'
        write(stdout,*) ' *** Compute  uHu '
        write(stdout,*) ' -----------------'
        write(stdout,*)
        iun_uhu = find_free_unit()
        if (ionode) then
           CALL date_and_tim( cdate, ctime )
           header='Created on '//cdate//' at '//ctime
           if(uHu_formatted) then
              open  (unit=iun_uhu, file=TRIM(seedname)//".uHu",form='FORMATTED')
              write (iun_uhu,*) header
              write (iun_uhu,*) nbnd-nexband, iknum, nnb
           else
              open  (unit=iun_uhu, file=TRIM(seedname)//".uHu",form='UNFORMATTED')
              write (iun_uhu) header
              write (iun_uhu) nbnd-nexband, iknum, nnb
           endif
        endif
     endif
     if(write_uIu) then
        write(stdout,*)
        write(stdout,*) ' -----------------'
        write(stdout,*) ' *** Compute  uIu '
        write(stdout,*) ' -----------------'
        write(stdout,*)
        iun_uIu = find_free_unit()
        if (ionode) then
           CALL date_and_tim( cdate, ctime )
           header='Created on '//cdate//' at '//ctime
           if(uIu_formatted) then
              open  (unit=iun_uIu, file=TRIM(seedname)//".uIu",form='FORMATTED')
              write (iun_uIu,*) header
              write (iun_uIu,*) nbnd-nexband, iknum, nnb
           else
              open  (unit=iun_uIu, file=TRIM(seedname)//".uIu",form='UNFORMATTED')
              write (iun_uIu) header
              write (iun_uIu) nbnd-nexband, iknum, nnb
           endif
        endif
     endif

     CALL set_vrs(vrs,vltot,v%of_r,kedtau,v%kin_r,dfftp%nnr,nspin,doublegrid)
     call allocate_bec_type ( nkb, nbnd, becp )
!     ALLOCATE( workg(npwx) )

     write(stdout,'(a,i8)') ' iknum = ',iknum
     do ik = 1, iknum ! loop over k points
        !
        write (stdout,'(i8)') ik
        !
        npw = ngk(ik)
        ! sort the wfc at k and set up stuff for h_psi
        current_k=ik+ikstart-1
        IF ( lsda ) current_spin = isk ( current_k )
        CALL init_us_2(npw,igk_k(1,ik),xk(1,ik),vkb)
        !
        ! compute  " H | u_n,k+b2 > "
        !
        do i_b2 = 1, nnb ! nnb = # of nearest neighbors
           !
           ! read wfc at k+b2
           ikp_b2 = kpb(ik,i_b2) ! for kpoint 'ik', index of neighbor 'i_b2'
           !
!           call davcio  (evc_b2, 2*nwordwfc, iunwfc, ikp_b2, -1 ) !ivo
           call davcio  (evc_b2, 2*nwordwfc, iunwfc, ikp_b2+ikstart-1, -1 ) !ivo
!           call gk_sort (xk(1,ikp_b2), ngm, g, gcutw, npw_b2, igk_b2, workg)
! ivo; igkq -> igk_k(:,ikp_b2), npw_b2 -> ngk(ikp_b2), replaced by PG
           npw_b2=ngk(ikp_b2)
           !
           ! compute the phase
           IF (.not.zerophase(ik,i_b2)) THEN
              phase(:) = ( 0.0D0, 0.0D0 )
              if (ig_(ik,i_b2)>0) phase( dffts%nl(ig_(ik,i_b2)) ) = ( 1.0D0, 0.0D0 )
              call invfft('Wave', phase, dffts)
           ENDIF
           !
           ! loop on bands
           evc_aux = ( 0.0D0, 0.0D0 )
           do n = 1, nbnd
              !ivo replaced dummy m --> n everywhere on this do loop,
              !    for consistency w/ band indices in comments
              if (excluded_band(n)) cycle
              if(noncolin) then
                 psic_nc = ( 0.0D0, 0.0D0 ) !ivo
                 do ipol = 1, 2
!                    psic_nc = ( 0.0D0, 0.0D0 ) !ivo
                    istart=(ipol-1)*npwx+1
                    iend=istart+npw_b2-1 !ivo npw_b1 --> npw_b2
                    psic_nc(dffts%nl (igk_k(1:npw_b2,ikp_b2) ),ipol ) = &
                         evc_b2(istart:iend, n)
                    IF (.not.zerophase(ik,i_b2)) THEN
                    ! ivo igk_b1, npw_b1 --> igk_b2, npw_b2
                    ! multiply by phase in real space - '1' unless neighbor is in a bordering BZ
                       call invfft ('Wave', psic_nc(:,ipol), dffts)
                       psic_nc(1:dffts%nnr,ipol) = psic_nc(1:dffts%nnr,ipol) * conjg(phase(1:dffts%nnr))
                       call fwfft ('Wave', psic_nc(:,ipol), dffts)
                    ENDIF
                    ! save the result
                    iend=istart+npw-1
                    evc_aux(istart:iend,n) = psic_nc(dffts%nl (igk_k(1:npw,ik) ),ipol )
                 end do
              else ! this is modeled after the pre-existing code at 1162
                 psic = ( 0.0D0, 0.0D0 )
                 ! Graham, changed npw --> npw_b2 on RHS. Do you agree?!
                 psic(dffts%nl (igk_k(1:npw_b2,ikp_b2) ) ) = evc_b2(1:npw_b2, n)
                 IF (.not.zerophase(ik,i_b2)) THEN
                    call invfft ('Wave', psic, dffts)
                    psic(1:dffts%nnr) = psic(1:dffts%nnr) * conjg(phase(1:dffts%nnr))
                    call fwfft ('Wave', psic, dffts)
                 ENDIF
                 evc_aux(1:npw,n) = psic(dffts%nl (igk_k(1:npw,ik) ) )
              end if
           end do !n

           if(write_uHu) then !ivo
              !
              ! calculate the kinetic energy at ik, used in h_psi
              !
              CALL g2_kin (ik)
              !
              CALL h_psi(npwx, npw, nbnd, evc_aux, H_evc)
              !
           endif
           !
           ! compute  " < u_m,k+b1 | "
           !
           do i_b1 = 1, nnb
              !
              ! read wfc at k+b1 !ivo replaced k+b2 --> k+b1
              ikp_b1 = kpb(ik,i_b1)
!              call davcio  (evc_b1, 2*nwordwfc, iunwfc, ikp_b1, -1 ) !ivo
              call davcio  (evc_b1, 2*nwordwfc, iunwfc, ikp_b1+ikstart-1, -1 ) !ivo

!              call gk_sort (xk(1,ikp_b1), ngm, g, gcutw, npw_b2, igk_b2, workg) !ivo
!              call gk_sort (xk(1,ikp_b1), ngm, g, gcutw, npw_b1, igk_b1, workg) !ivo
              npw_b1=ngk(ikp_b1)
              !
              ! compute the phase
              IF (.not.zerophase(ik,i_b1)) THEN
                 phase(:) = ( 0.0D0, 0.0D0 )
                 if (ig_(ik,i_b1)>0) phase( dffts%nl(ig_(ik,i_b1)) ) = ( 1.0D0, 0.0D0 )
                 !call cft3s (phase, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, +2)
                 call invfft('Wave', phase, dffts)
              ENDIF
              !
              ! loop on bands
              ibnd_m = 0
              do m = 1, nbnd
                 if (excluded_band(m)) cycle
                 ibnd_m = ibnd_m + 1
                 if(noncolin) then
                    aux_nc  = ( 0.0D0, 0.0D0 )
                    psic_nc = ( 0.0D0, 0.0D0 ) !ivo
                    do ipol = 1, 2
!                      psic_nc = ( 0.0D0, 0.0D0 ) !ivo
                       istart=(ipol-1)*npwx+1
                       iend=istart+npw_b1-1  !ivo npw_b2 --> npw_b1
                       psic_nc(dffts%nl (igk_k(1:npw_b1,ikp_b1) ),ipol ) = evc_b1(istart:iend, m) !ivo igk_b2,npw_b2 --> igk_b1,npw_b1
                       IF (.not.zerophase(ik,i_b1)) THEN
                          ! multiply by phase in real space - '1' unless neighbor is in a different BZ
                          call invfft ('Wave', psic_nc(:,ipol), dffts)
                          !psic_nc(1:nrxxs,ipol) = psic_nc(1:nrxxs,ipol) * conjg(phase(1:nrxxs))
                          psic_nc(1:dffts%nnr,ipol) = psic_nc(1:dffts%nnr,ipol) * conjg(phase(1:dffts%nnr))
                          call fwfft ('Wave', psic_nc(:,ipol), dffts)
                       ENDIF
                       ! save the result
                       aux_nc(1:npw,ipol) = psic_nc(dffts%nl (igk_k(1:npw,ik) ),ipol )
                    end do
                 else ! this is modeled after the pre-existing code at 1162
                    aux  = ( 0.0D0 )
                    psic = ( 0.0D0, 0.0D0 )
                    ! Graham, changed npw --> npw_b1 on RHS. Do you agree?!
!                    psic(dffts%nl (igk_b1(1:npw_b1) ) ) = evc_b1(1:npw_b1, m) !ivo igk_b2 --> igk_b1
                    psic(dffts%nl (igk_k(1:npw_b1,ikp_b1) ) ) = evc_b1(1:npw_b1, m) !ivo igk_b2 --> igk_b1
                    IF (.not.zerophase(ik,i_b1)) THEN
                       call invfft ('Wave', psic, dffts)
                       !psic(1:nrxxs) = psic(1:nrxxs) * conjg(phase(1:nrxxs))
                       psic(1:dffts%nnr) = psic(1:dffts%nnr) * conjg(phase(1:dffts%nnr))
                       call fwfft ('Wave', psic, dffts)
                    ENDIF
                    aux(1:npw) = psic(dffts%nl (igk_k(1:npw,ik) ) )
                 end if

                !
                !
                if(write_uHu) then !ivo
                   ibnd_n = 0
                   do n = 1, nbnd  ! loop over bands of already computed ket
                      if (excluded_band(n)) cycle
                      ibnd_n = ibnd_n + 1
                      if(noncolin) then
                         mmn = zdotc (npw, aux_nc(1,1),1,H_evc(1,n),1) + &
                              zdotc (npw, aux_nc(1,2),1,H_evc(1+npwx,n),1)
                      else
                         mmn = zdotc (npw, aux,1,H_evc(1,n),1)
                      end if
                      mmn = mmn * rytoev ! because wannier90 works in eV
                      call mp_sum(mmn, intra_pool_comm)
!                      if (ionode) write (iun_uhu) mmn
                      uHu(ibnd_n,ibnd_m)=mmn
                      !
                   end do !n
                endif
                if(write_uIu) then !ivo
                   ibnd_n = 0
                   do n = 1, nbnd  ! loop over bands of already computed ket
                      if (excluded_band(n)) cycle
                      ibnd_n = ibnd_n + 1
                      if(noncolin) then
                         mmn = zdotc (npw, aux_nc(1,1),1,evc_aux(1,n),1) + &
                              zdotc (npw, aux_nc(1,2),1,evc_aux(1+npwx,n),1)
                      else
                         mmn = zdotc (npw, aux,1,evc_aux(1,n),1)
                      end if
                      call mp_sum(mmn, intra_pool_comm)
!                      if (ionode) write (iun_uIu) mmn
                      uIu(ibnd_n,ibnd_m)=mmn
                      !
                   end do !n
                endif
                !
             end do ! m = 1, nbnd
             if (ionode) then  ! write the files out to disk
                if(write_uhu) then
                   if(uHu_formatted) then ! slow bulky way for transferable files
                      do n=1,num_bands
                         do m=1,num_bands
                            write(iun_uHu,'(2ES20.10)') uHu(m,n)
                         enddo
                      enddo
                   else  ! the fast way
                      write(iun_uHu) ((uHu(n,m),n=1,num_bands),m=1,num_bands)
                   endif
                endif
                if(write_uiu) then
                   if(uIu_formatted) then ! slow bulky way for transferable files
                      do n=1,num_bands
                         do m=1,num_bands
                            write(iun_uIu,'(2ES20.10)') uIu(m,n)
                         enddo
                      enddo
                   else ! the fast way
                      write(iun_uIu) ((uIu(n,m),n=1,num_bands),m=1,num_bands)
                   endif
                endif
             endif ! end of io
          end do ! i_b1
       end do ! i_b2
    end do ! ik
    !
    deallocate(evc_b1,evc_b2,evc_aux)
    if(write_uHu) then
       deallocate(H_evc)
       deallocate(uHu)
    end if
    if(write_uIu) deallocate(uIu)
    if (ionode.and.write_uHu) close (iun_uhu) !ivo
    if (ionode.and.write_uIu) close (iun_uIu) !ivo
    !
 else
    if(.not.write_uHu) then
       write(stdout,*)
       write(stdout,*) ' -------------------------------'
       write(stdout,*) ' *** uHu matrix is not computed '
       write(stdout,*) ' -------------------------------'
       write(stdout,*)
    endif
    if(.not.write_uIu) then
       write(stdout,*)
       write(stdout,*) ' -------------------------------'
       write(stdout,*) ' *** uIu matrix is not computed '
       write(stdout,*) ' -------------------------------'
       write(stdout,*)
    endif
 end if
   !
   !
   !
   !
   !
   !
   !====================================================================
   !
   ! END_m_orbit
   !
   !====================================================================
   !
   ! end change Lopez, Thonhauser, Souza
   !
   !
   !

!   IF (gamma_only) DEALLOCATE(aux2)
   DEALLOCATE (phase)
   IF(noncolin) THEN
      DEALLOCATE(aux_nc)
   ELSE
      DEALLOCATE(aux)
   ENDIF
   DEALLOCATE(evcq)

!   IF(any_uspp) THEN
!      DEALLOCATE (  qb)
!      CALL deallocate_bec_type (becp)
!      IF (gamma_only) THEN
!          DEALLOCATE (rbecp2)
!       ELSE
!          DEALLOCATE (becp2)
!       ENDIF
!    ENDIF
   CALL deallocate_bec_type (becp)
!
   WRITE(stdout,*)
   if(write_uHu) WRITE(stdout,*) ' uHu calculated'
   if(write_uIu) WRITE(stdout,*) ' uIu calculated'

   RETURN
END SUBROUTINE compute_orb
!
!-----------------------------------------------------------------------
SUBROUTINE compute_shc
   !-----------------------------------------------------------------------
   !
   USE kinds,           ONLY : DP
   USE mp,              ONLY : mp_sum
   USE mp_global,       ONLY : intra_pool_comm
   USE io_global,       ONLY : stdout, ionode
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE constants,       ONLY : rytoev
   USE fft_base,        ONLY : dffts, dfftp
   USE fft_interfaces,  ONLY : fwfft, invfft
   USE control_flags,   ONLY : gamma_only
   USE wvfct,           ONLY : nbnd, npwx, current_k
   USE wavefunctions,   ONLY : evc, psic_nc
   USE klist,           ONLY : xk, ngk, igk_k
   USE uspp,            ONLY : nkb, vkb, okvan
   USE uspp_param,      ONLY : upf
   USE becmod,          ONLY : bec_type, becp, calbec, &
                               allocate_bec_type, deallocate_bec_type
   USE gvecs,           ONLY : doublegrid
   USE noncollin_module,ONLY : noncolin, npol
   USE lsda_mod,        ONLY : nspin
   USE scf,             ONLY : vrs, vltot, v, kedtau
   USE wannier
   USE uspp_init,            ONLY : init_us_2
   !
   IMPLICIT NONE
   !
   COMPLEX(DP), parameter :: cmplx_i = (0.0_DP, 1.0_DP)
   !
   CHARACTER (len=9) :: cdate,ctime
   CHARACTER (len=header_len) :: header
   LOGICAL :: any_uspp
   INTEGER :: ik, ipol, npw, m, n
   INTEGER :: ikevc
   INTEGER :: istart, iend
   INTEGER :: ispol, npw_b2, i_b2, ikp_b2
   INTEGER :: ibnd_n, ibnd_m
   COMPLEX(DP) :: sigma_x, sigma_y, sigma_z, cdum1, cdum2
   !
   COMPLEX(DP), ALLOCATABLE :: phase(:)
   COMPLEX(DP), ALLOCATABLE :: evc_b2(:, :), evc_aux(:, :), H_evc(:, :)
   COMPLEX(DP), ALLOCATABLE :: sHu(:, : ,:),sIu(:, :, :)
   !
   IF (.NOT. (write_sHu .OR. write_sIu)) THEN
      WRITE(stdout, *)
      WRITE(stdout, *) ' ----------------------------------------'
      WRITE(stdout, *) ' *** sHu and sIu matrix are not computed '
      WRITE(stdout, *) ' ----------------------------------------'
      WRITE(stdout, *)
      !
      RETURN
      !
   ENDIF
   !
   CALL start_clock('compute_shc')
   !
   !ivo
   ! not sure this is really needed
   IF (wan_mode == 'library') CALL errore('pw2wannier90', &
      'write_sHu, and write_sIu not meant to work library mode', 1)
   !endivo
   !
   IF (gamma_only) CALL errore('pw2wannier90',&
      'write_sHu and write_sIu not yet implemented for gamma_only case', 1)
   IF (okvan) CALL errore('pw2wannier90',&
      'write_sHu and write_sIu not yet implemented with USPP', 1)
   IF (.NOT. noncolin) CALL errore('pw2wannier90',&
      'write_sHu and write_sIu only works with noncolin == .true.', 1)
   !
   ALLOCATE(evc_b2(npol*npwx, nbnd))
   ALLOCATE(evc_aux(npol*npwx, nbnd))
   ALLOCATE(phase(dffts%nnr) )
   !
   IF (write_sHu) THEN
      ALLOCATE(sHu(num_bands, num_bands, 3))
      ALLOCATE(H_evc(npol*npwx, nbnd))
   ENDIF
   IF (write_sIu) ALLOCATE(sIu(num_bands, num_bands, 3))
   !
   !
   IF (write_sHu) THEN
      write(stdout,*) ' *** Computing  sHu '
      IF (ionode) THEN
         CALL date_and_tim( cdate, ctime )
         header = 'Created on '//cdate//' at '//ctime
         IF (sHu_formatted) THEN
            OPEN (newunit=iun_sHu, file=TRIM(seedname)//".sHu", form='FORMATTED')
            WRITE(iun_sHu, *) header
            WRITE(iun_sHu, *) num_bands, iknum, nnb
         ELSE
            OPEN (newunit=iun_sHu, file=TRIM(seedname)//".sHu", form='UNFORMATTED')
            WRITE(iun_sHu) header
            WRITE(iun_sHu) num_bands, iknum, nnb
         ENDIF
      ENDIF
   ENDIF
   IF (write_sIu) THEN
      WRITE(stdout,*) ' *** Computing  sIu '
      IF (ionode) THEN
         CALL date_and_tim( cdate, ctime )
         header = 'Created on '//cdate//' at '//ctime
         IF (sIu_formatted) THEN
            OPEN (newunit=iun_sIu, file=TRIM(seedname)//".sIu", form='FORMATTED')
            WRITE(iun_sIu, *) header
            WRITE(iun_sIu, *) num_bands, iknum, nnb
         ELSE
            OPEN (newunit=iun_sIu, file=TRIM(seedname)//".sIu", form='UNFORMATTED')
            WRITE(iun_sIu) header
            WRITE(iun_sIu) num_bands, iknum, nnb
         ENDIF
      ENDIF
   ENDIF
   !
   CALL set_vrs(vrs, vltot, v%of_r, kedtau, v%kin_r, dfftp%nnr, nspin, doublegrid)
   CALL allocate_bec_type(nkb, nbnd, becp)
   !
   WRITE(stdout, *)
   WRITE(stdout, '(a,i8)') ' iknum = ', iknum
   !
   DO ik = 1, iknum ! loop over k points
      !
      WRITE(stdout, '(i8)', advance='no') ik
      IF (MOD(ik, 10) == 0) WRITE (stdout, *)
      FLUSH(stdout)
      !
      npw = ngk(ik)
      !
      ikevc = ik + ikstart - 1
      CALL davcio(evc, 2*nwordwfc, iunwfc, ikevc, -1)
      !
      ! sort the wfc at k and set up stuff for h_psi
      current_k = ik
      CALL init_us_2(npw, igk_k(1,ik), xk(1,ik), vkb)
      !
      ! compute  " H | u_n,k+b2 > "
      !
      DO i_b2 = 1, nnb ! nnb = # of nearest neighbors
         !
         ! read wfc at k+b2
         ikp_b2 = kpb(ik, i_b2) ! for kpoint 'ik', index of neighbor 'i_b2'
         !
         CALL davcio(evc_b2, 2*nwordwfc, iunwfc, ikp_b2+ikstart-1, -1) !ivo
         npw_b2 = ngk(ikp_b2)
         !
         ! compute the phase only if phase is not 1.
         IF (.NOT. zerophase(ik, i_b2)) THEN
            phase(:) = ( 0.0D0, 0.0D0 )
            IF (ig_(ik,i_b2)>0) phase( dffts%nl(ig_(ik,i_b2)) ) = ( 1.0D0, 0.0D0 )
            CALL invfft('Wave', phase, dffts)
         ENDIF
         !
         ! loop on bands
         evc_aux = ( 0.0D0, 0.0D0 )
         DO n = 1, nbnd
            IF (excluded_band(n)) CYCLE
            psic_nc = ( 0.0D0, 0.0D0 )
            DO ipol = 1, 2
               istart = (ipol-1) * npwx + 1
               iend = istart + npw_b2 - 1
               psic_nc(dffts%nl(igk_k(1:npw_b2,ikp_b2)), ipol) = evc_b2(istart:iend, n)
               !
               ! multiply by phase in real space if phase is not 1.
               ! Phase is '1' unless neighbor is in a bordering BZ
               IF (.NOT. zerophase(ik, i_b2)) THEN
                  CALL invfft('Wave', psic_nc(:,ipol), dffts)
                  psic_nc(1:dffts%nnr,ipol) = psic_nc(1:dffts%nnr,ipol) * CONJG(phase(1:dffts%nnr))
                  CALL fwfft('Wave', psic_nc(:,ipol), dffts)
               ENDIF
               !
               ! save the result
               iend = istart + npw - 1
               evc_aux(istart:iend, n) = psic_nc(dffts%nl (igk_k(1:npw,ik) ), ipol )
            ENDDO ! ipol
         ENDDO ! n
         !
         IF (write_sHu) THEN !ivo
            !
            ! calculate the kinetic energy at ik, used in h_psi
            !
            CALL g2_kin(ik)
            !
            CALL h_psi(npwx, npw, nbnd, evc_aux, H_evc)
            !
         ENDIF
         !
         sHu = (0.D0, 0.D0)
         sIu = (0.D0, 0.D0)
         !
         ! loop on bands
         ibnd_m = 0
         DO m = 1, nbnd
            IF (excluded_band(m)) CYCLE
            ibnd_m = ibnd_m + 1
            !
            ibnd_n = 0
            DO n = 1, nbnd  ! loop over bands of already computed ket
               IF (excluded_band(n)) CYCLE
               ibnd_n = ibnd_n + 1
               !
               ! <a|sx|b> = (a2, b1) + (a1, b2)
               ! <a|sy|b> = I (a2, b1) - I (a1, b2)
               ! <a|sz|b> = (a1, b1) - (a2, b2)
               !
               IF (write_sHu) THEN !ivo
                  cdum1 = dot_product(evc(1:npw, m), H_evc(npwx+1:npwx+npw, n))
                  cdum2 = dot_product(evc(npwx+1:npwx+npw, m), H_evc(1:npw, n))
                  sigma_x = cdum1 + cdum2
                  sigma_y = cmplx_i * (cdum2 - cdum1)
                  sigma_z = dot_product(evc(1:npw, m), H_evc(1:npw, n)) &
                          - dot_product(evc(npwx+1:npwx+npw, m), H_evc(npwx+1:npwx+npw, n))
                  !
                  sHu(ibnd_n, ibnd_m, 1) = sigma_x * rytoev
                  sHu(ibnd_n, ibnd_m, 2) = sigma_y * rytoev
                  sHu(ibnd_n, ibnd_m, 3) = sigma_z * rytoev
               ENDIF ! write_sHu
               !
               IF (write_sIu) THEN !ivo
                  cdum1 = dot_product(evc(1:npw, m), evc_aux(npwx+1:npwx+npw, n))
                  cdum2 = dot_product(evc(npwx+1:npwx+npw, m), evc_aux(1:npw, n))
                  sigma_x = cdum1 + cdum2
                  sigma_y = cmplx_i * (cdum2 - cdum1)
                  sigma_z = dot_product(evc(1:npw, m), evc_aux(1:npw, n)) &
                          - dot_product(evc(npwx+1:npwx+npw, m), evc_aux(npwx+1:npwx+npw, n))
                  !
                  sIu(ibnd_n, ibnd_m, 1) = sigma_x
                  sIu(ibnd_n, ibnd_m, 2) = sigma_y
                  sIu(ibnd_n, ibnd_m, 3) = sigma_z
               ENDIF ! write_sIu
            ENDDO ! n
            !
         ENDDO ! m
         !
         IF (write_sHu) CALL mp_sum(sHu, intra_pool_comm)
         IF (write_sIu) CALL mp_sum(sIu, intra_pool_comm)
         !
         IF (ionode) THEN  ! write the files out to disk
            DO ispol = 1, 3
               IF (write_sHu) THEN
                  IF (sHu_formatted) THEN ! slow bulky way for transferable files
                     DO n = 1, num_bands
                        DO m = 1, num_bands
                           WRITE(iun_sHu, '(2ES20.10)') sHu(m,n,ispol)
                        ENDDO
                     ENDDO
                  ELSE  ! the fast way
                     WRITE(iun_sHu) ((sHu(n,m,ispol), n=1,num_bands), m=1,num_bands)
                  ENDIF
               ENDIF
               IF (write_sHu) THEN
                  IF (sIu_formatted) THEN ! slow bulky way for transferable files
                     DO n = 1, num_bands
                        DO m = 1, num_bands
                           WRITE(iun_sIu, '(2ES20.10)') sIu(m,n,ispol)
                        ENDDO
                     ENDDO
                  ELSE ! the fast way
                     WRITE(iun_sIu) ((sIu(n,m,ispol), n=1,num_bands), m=1,num_bands)
                  ENDIF
               ENDIF
            ENDDO
         ENDIF ! end of io
         !
      ENDDO ! i_b2
   ENDDO ! ik
   !
   DEALLOCATE(evc_b2)
   DEALLOCATE(evc_aux)
   DEALLOCATE(phase)
   IF (write_sHu) THEN
      DEALLOCATE(H_evc)
      DEALLOCATE(sHu)
   ENDIF
   IF (write_sIu) DEALLOCATE(sIu)
   !
   IF (ionode .AND. write_sHu) CLOSE(iun_sHu)
   IF (ionode .AND. write_sIu) CLOSE(iun_sIu)
   !
   WRITE(stdout,*)
   WRITE(stdout,*) ' shc calculated'
   !
   CALL stop_clock('compute_shc')
   !
   RETURN
   !
END SUBROUTINE
!-----------------------------------------------------------------------
SUBROUTINE compute_amn
   !-----------------------------------------------------------------------
   !
   USE io_global,  ONLY : stdout, ionode
   USE kinds,           ONLY : DP
   USE klist,           ONLY : nkstot, xk, ngk, igk_k
   USE wvfct,           ONLY : nbnd, npwx
   USE control_flags,   ONLY : gamma_only
   USE wavefunctions, ONLY : evc
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE gvect,           ONLY : g, ngm, gstart
   USE uspp,            ONLY : nkb, vkb
   USE becmod,          ONLY : bec_type, becp, calbec, &
                               allocate_bec_type, deallocate_bec_type
   USE wannier
   USE ions_base,       ONLY : nat, ntyp => nsp, ityp, tau
   USE uspp_param,      ONLY : upf
   USE mp_pools,        ONLY : intra_pool_comm
   USE mp,              ONLY : mp_sum
   USE noncollin_module,ONLY : noncolin, npol
   USE gvecw,           ONLY : gcutw
   USE constants,       ONLY : eps6
   USE uspp_init,       ONLY : init_us_2

   IMPLICIT NONE
   !
   INTEGER, EXTERNAL :: find_free_unit
   !
   COMPLEX(DP) :: amn, zdotc,amn_tmp,fac(2)
   real(DP):: ddot
   COMPLEX(DP), ALLOCATABLE :: sgf(:,:)
   INTEGER :: ik, npw, ibnd, ibnd1, iw,i, ikevc, nt, ipol
   CHARACTER (len=9)  :: cdate,ctime
   CHARACTER (len=header_len) :: header
   LOGICAL            :: any_uspp, opnd, exst,spin_z_pos, spin_z_neg
   INTEGER            :: istart, ierr

   !nocolin: we have half as many projections g(r) defined as wannier
   !         functions. We project onto (1,0) (ie up spin) and then onto
   !         (0,1) to obtain num_wann projections. jry


   !call read_gf_definition.....>   this is done at the beging

   CALL start_clock( 'compute_amn' )

   any_uspp = any(upf(1:ntyp)%tvanp)

   IF (wan_mode=='library') THEN
      ALLOCATE(a_mat(num_bands,n_wannier,iknum), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating a_mat', 1)
   END IF

   IF (wan_mode=='standalone') THEN
      iun_amn = find_free_unit()
      IF (ionode) THEN
         IF (irr_bz) THEN
            OPEN (unit=iun_amn, file=trim(seedname)//".iamn",form='formatted')
         ELSE
            OPEN (unit=iun_amn, file=trim(seedname)//".amn",form='formatted')
         ENDIF
      ENDIF
   ENDIF

   WRITE(stdout,'(a,i8)') '  AMN: iknum = ',iknum
   !
   IF (wan_mode=='standalone') THEN
      CALL date_and_tim( cdate, ctime )
      header='Created on '//cdate//' at '//ctime
      IF (ionode) THEN
         WRITE (iun_amn,*) header
         WRITE (iun_amn,*) nbnd-nexband, iknum, n_wannier
         !WRITE (iun_amn,*) nbnd-nexband,  iknum, n_proj
      ENDIF
   ENDIF
   !
   ALLOCATE( sgf(npwx,n_proj), stat=ierr)
   IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating sgf', 1)
   ALLOCATE( gf_spinor(2*npwx,n_proj), stat=ierr)
   IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating gf_spinor', 1)
   ALLOCATE( sgf_spinor(2*npwx,n_proj), stat=ierr)
   IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating sgf_spinor', 1)
   !
   IF (any_uspp) THEN
      CALL allocate_bec_type ( nkb, n_wannier, becp)
   ENDIF
   !

   DO ik=1,iknum
      WRITE (stdout,'(i8)',advance='no') ik
      IF( MOD(ik,10) == 0 ) WRITE (stdout,*)
      FLUSH(stdout)
      ikevc = ik + ikstart - 1
!      if(noncolin) then
!         call davcio (evc_nc, 2*nwordwfc, iunwfc, ikevc, -1 )
!      else
         CALL davcio (evc, 2*nwordwfc, iunwfc, ikevc, -1 )
!      end if
      npw = ngk(ik)
      CALL generate_guiding_functions(ik)   ! they are called gf(npw,n_proj)

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      if(noncolin) then
        sgf_spinor = (0.d0,0.d0)
        call orient_gf_spinor(npw)
      endif

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      !
      !  USPP
      !
      IF(any_uspp) THEN
         CALL init_us_2 (npw, igk_k(1,ik), xk (1, ik), vkb)
         ! below we compute the product of beta functions with trial func.
         IF (gamma_only) THEN
            CALL calbec ( npw, vkb, gf, becp, n_proj )
         ELSE if (noncolin) then
            CALL calbec ( npw, vkb, gf_spinor, becp, n_proj )
         else
            CALL calbec ( npw, vkb, gf, becp, n_proj )
         ENDIF
         ! and we use it for the product S|trial_func>
         if (noncolin) then
           CALL s_psi (npwx, npw, n_proj, gf_spinor, sgf_spinor)
         else
           CALL s_psi (npwx, npw, n_proj, gf, sgf)
         endif

      ELSE
         !if (noncolin) then
         !   sgf_spinor(:,:) = gf_spinor
         !else
            sgf(:,:) = gf(:,:)
         !endif
      ENDIF
      !
      noncolin_case : &
      IF(noncolin) THEN
         old_spinor_proj_case : &
         IF(old_spinor_proj) THEN
            ! we do the projection as g(r)*a(r) and g(r)*b(r)
            DO ipol=1,npol
               istart = (ipol-1)*npwx + 1
               DO iw = 1,n_proj
                  ibnd1 = 0
                  DO ibnd = 1,nbnd
                     IF (excluded_band(ibnd)) CYCLE
                     amn=(0.0_dp,0.0_dp)
                     !                  amn = zdotc(npw,evc_nc(1,ipol,ibnd),1,sgf(1,iw),1)
                     if (any_uspp) then
                        amn = zdotc(npw, evc(0,ibnd), 1, sgf_spinor(1, iw + (ipol-1)*n_proj), 1)
                        amn = amn + zdotc(npw, evc(npwx+1,ibnd), 1, sgf_spinor(npwx+1, iw + (ipol-1)*n_proj), 1)
                     else
                        amn = zdotc(npw,evc(istart,ibnd),1,sgf(1,iw),1)
                     endif
                     CALL mp_sum(amn, intra_pool_comm)
                     ibnd1=ibnd1+1
                     IF (wan_mode=='standalone') THEN
                        IF (ionode) WRITE(iun_amn,'(3i5,2f18.12)') ibnd1, iw+n_proj*(ipol-1), ik, amn
                     ELSEIF (wan_mode=='library') THEN
                        a_mat(ibnd1,iw+n_proj*(ipol-1),ik) = amn
                     ELSE
                        CALL errore('compute_amn',' value of wan_mode not recognised',1)
                     ENDIF
                  ENDDO
               ENDDO
            ENDDO
         ELSE old_spinor_proj_case
            DO iw = 1,n_proj
               spin_z_pos=.false.;spin_z_neg=.false.
               ! detect if spin quantisation axis is along z
               if((abs(spin_qaxis(1,iw)-0.0d0)<eps6).and.(abs(spin_qaxis(2,iw)-0.0d0)<eps6) &
                    .and.(abs(spin_qaxis(3,iw)-1.0d0)<eps6)) then
                  spin_z_pos=.true.
               elseif(abs(spin_qaxis(1,iw)-0.0d0)<eps6.and.abs(spin_qaxis(2,iw)-0.0d0)<eps6 &
                    .and.abs(spin_qaxis(3,iw)+1.0d0)<eps6) then
                  spin_z_neg=.true.
               endif
               if(spin_z_pos .or. spin_z_neg) then
                  ibnd1 = 0
                  DO ibnd = 1,nbnd
                     IF (excluded_band(ibnd)) CYCLE
                     if(spin_z_pos) then
                        ipol=(3-spin_eig(iw))/2
                     else
                        ipol=(3+spin_eig(iw))/2
                     endif
                     istart = (ipol-1)*npwx + 1
                     amn=(0.0_dp,0.0_dp)
                     if (any_uspp) then
                        amn = zdotc(npw, evc(1, ibnd), 1, sgf_spinor(1, iw), 1)
                        amn = amn + zdotc(npw, evc(npwx+1, ibnd), 1, sgf_spinor(npwx+1, iw), 1)
                     else
                        amn = zdotc(npw,evc(istart,ibnd),1,sgf(1,iw),1)
                     endif
                     CALL mp_sum(amn, intra_pool_comm)
                     ibnd1=ibnd1+1
                     IF (wan_mode=='standalone') THEN
                        IF (ionode) WRITE(iun_amn,'(3i5,2f18.12)') ibnd1, iw, ik, amn
                     ELSEIF (wan_mode=='library') THEN
                        a_mat(ibnd1,iw+n_proj*(ipol-1),ik) = amn
                     ELSE
                        CALL errore('compute_amn',' value of wan_mode not recognised',1)
                     ENDIF
                  ENDDO
               else
                  ! general routine
                  ! for quantisation axis (a,b,c)
                  ! 'up'    eigenvector is 1/sqrt(1+c) [c+1,a+ib]
                  ! 'down'  eigenvector is 1/sqrt(1-c) [c-1,a+ib]
                  if(spin_eig(iw)==1) then
                     fac(1)=(1.0_dp/sqrt(1+spin_qaxis(3,iw)))*(spin_qaxis(3,iw)+1)*cmplx(1.0d0,0.0d0,dp)
                     fac(2)=(1.0_dp/sqrt(1+spin_qaxis(3,iw)))*cmplx(spin_qaxis(1,iw),spin_qaxis(2,iw),dp)
                  else
                     fac(1)=(1.0_dp/sqrt(1-spin_qaxis(3,iw)))*(spin_qaxis(3,iw)-1)*cmplx(1.0d0,0.0d0,dp)
                     fac(2)=(1.0_dp/sqrt(1-spin_qaxis(3,iw)))*cmplx(spin_qaxis(1,iw),spin_qaxis(2,iw),dp)
                  endif
                  ibnd1 = 0
                  DO ibnd = 1,nbnd
                     IF (excluded_band(ibnd)) CYCLE
                     amn=(0.0_dp,0.0_dp)
                     DO ipol=1,npol
                        istart = (ipol-1)*npwx + 1
                        amn_tmp=(0.0_dp,0.0_dp)
                        if (any_uspp) then
                          amn_tmp = zdotc(npw,evc(istart,ibnd),1,sgf_spinor(istart,iw),1)
                          CALL mp_sum(amn_tmp, intra_pool_comm)
                          amn=amn+amn_tmp
                        else
                          amn_tmp = zdotc(npw,evc(istart,ibnd),1,sgf(1,iw),1)
                          CALL mp_sum(amn_tmp, intra_pool_comm)
                          amn=amn+fac(ipol)*amn_tmp
                        endif
                     enddo
                     ibnd1=ibnd1+1
                     IF (wan_mode=='standalone') THEN
                        IF (ionode) WRITE(iun_amn,'(3i5,2f18.12)') ibnd1, iw, ik, amn
                     ELSEIF (wan_mode=='library') THEN
                           a_mat(ibnd1,iw+n_proj*(ipol-1),ik) = amn
                        ELSE
                           CALL errore('compute_amn',' value of wan_mode not recognised',1)
                        ENDIF
                     ENDDO
                  endif
               end do
            endif old_spinor_proj_case
         ELSE  noncolin_case ! scalar wfcs
            DO iw = 1,n_proj
               ibnd1 = 0
               DO ibnd = 1,nbnd
                  IF (excluded_band(ibnd)) CYCLE
                  IF (gamma_only) THEN
                     amn = 2.0_dp*ddot(2*npw,evc(1,ibnd),1,sgf(1,iw),1)
                     IF (gstart==2) amn = amn - real(conjg(evc(1,ibnd))*sgf(1,iw))
                  ELSE
                     amn = zdotc(npw,evc(1,ibnd),1,sgf(1,iw),1)
                  ENDIF
                  CALL mp_sum(amn, intra_pool_comm)
                  ibnd1=ibnd1+1
                  IF (wan_mode=='standalone') THEN
                     IF (ionode) WRITE(iun_amn,'(3i5,2f18.12)') ibnd1, iw, ik, amn
                  ELSEIF (wan_mode=='library') THEN
                     a_mat(ibnd1,iw,ik) = amn
                  ELSE
                     CALL errore('compute_amn',' value of wan_mode not recognised',1)
                  ENDIF
               ENDDO
            ENDDO
         ENDIF noncolin_case
      ENDDO  ! k-points
      DEALLOCATE (sgf,csph, gf_spinor, sgf_spinor)
   IF(any_uspp) THEN
     CALL deallocate_bec_type (becp)
   ENDIF
   !
   IF (ionode .and. wan_mode=='standalone') CLOSE (iun_amn)

   WRITE(stdout,'(/)')
   WRITE(stdout,*) ' AMN calculated'

   ! vv: This should be here and not in write_band
   CALL stop_clock( 'compute_amn' )
   RETURN
END SUBROUTINE compute_amn

SUBROUTINE compute_amn_with_scdm
   USE constants,       ONLY : rytoev, pi
   USE io_global,       ONLY : stdout, ionode, ionode_id
   USE wvfct,           ONLY : nbnd, et
   USE gvecw,           ONLY : gcutw
   USE control_flags,   ONLY : gamma_only
   USE wavefunctions, ONLY : evc, psic
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE wannier
   USE klist,           ONLY : nkstot, xk, ngk, igk_k
   USE gvect,           ONLY : g, ngm, mill
   USE fft_base,        ONLY : dffts !vv: unk for the SCDM-k algorithm
   USE scatter_mod,     ONLY : gather_grid
   USE fft_interfaces,  ONLY : invfft !vv: inverse fft transform for computing the unk's on a grid
   USE noncollin_module,ONLY : noncolin, npol
   USE mp,              ONLY : mp_bcast, mp_barrier, mp_sum
   USE mp_world,        ONLY : world_comm, mpime, nproc
   USE mp_pools,        ONLY : intra_pool_comm
   USE cell_base,       ONLY : at
   USE ions_base,       ONLY : ntyp => nsp, tau
   USE uspp_param,      ONLY : upf

   IMPLICIT NONE

   INTEGER, EXTERNAL :: find_free_unit
   COMPLEX(DP), ALLOCATABLE :: phase(:), nowfc1(:,:), nowfc(:,:), psi_gamma(:,:), &
       qr_tau(:), cwork(:), cwork2(:), Umat(:,:), VTmat(:,:), Amat(:,:) ! vv: complex arrays for the SVD factorization
   COMPLEX(DP), ALLOCATABLE :: phase_g(:,:) ! jml
   REAL(DP), ALLOCATABLE :: focc(:), rwork(:), rwork2(:), singval(:), rpos(:,:), cpos(:,:) ! vv: Real array for the QR factorization and SVD
   INTEGER, ALLOCATABLE :: piv(:) ! vv: Pivot array in the QR factorization
   COMPLEX(DP) :: tmp_cwork(2)
   COMPLEX(DP) :: nowfc_tmp ! jml
   REAL(DP):: ddot, sumk, norm_psi, f_gamma, tpi_r_dot_g
   INTEGER :: ik, npw, ibnd, iw, ikevc, nrtot, ipt, info, lcwork, locibnd, &
              jpt,kpt,lpt, ib, istart, gamma_idx, minmn, minmn2, maxmn2, numbands, nbtot, &
              ig, ig_local ! jml
   CHARACTER (len=9)  :: cdate,ctime
   CHARACTER (len=header_len) :: header
   LOGICAL            :: any_uspp, found_gamma

#if defined(__SCALAPACK_QRCP)
   REAL(DP) :: tmp_rwork(2)
   INTEGER :: lrwork, context, nprow, npcol, myrow, mycol, descG(9)
   INTEGER :: nblocks, rem, nblocks_loc, rem_loc=0, ibl
   INTEGER, ALLOCATABLE :: piv_p(:)
#endif

#if defined(__MPI)
   INTEGER :: nxxs
   COMPLEX(DP),ALLOCATABLE :: psic_all(:)
   nxxs = dffts%nr1x * dffts%nr2x * dffts%nr3x
   ALLOCATE(psic_all(nxxs) )
#endif

   ! vv: Write info about SCDM in output
   IF (TRIM(scdm_entanglement) == 'isolated') THEN
      WRITE(stdout,'(1x,a,a/)') 'Case  : ',trim(scdm_entanglement)
   ELSEIF (TRIM(scdm_entanglement) == 'erfc' .OR. &
        TRIM(scdm_entanglement) == 'gaussian') THEN
      WRITE(stdout,'(1x,a,a)') 'Case  : ',trim(scdm_entanglement)
      WRITE(stdout,'(1x,a,f10.3,a/,1x,a,f10.3,a/)') 'mu    = ', scdm_mu, ' eV', 'sigma =', scdm_sigma, ' eV'
   ENDIF

   CALL start_clock( 'compute_amn' )

   any_uspp =any (upf(1:ntyp)%tvanp)

   ! vv: Error for using SCDM with Ultrasoft pseudopotentials
   !IF (any_uspp) THEN
   !   call errore('pw2wannier90','The SCDM method does not work with Ultrasoft pseudopotential yet.',1)
   !ENDIF

   ! vv: Error for using SCDM with gamma_only
   IF (gamma_only) THEN
      call errore('pw2wannier90','The SCDM method does not work with gamma_only calculations.',1)
   ENDIF
   ! vv: Allocate all the variables for the SCDM method:
   !     1)For the QR decomposition
   !     2)For the unk's on the real grid
   !     3)For the SVD
   IF(TRIM(scdm_entanglement) == 'isolated') THEN
      numbands=n_wannier
      nbtot=n_wannier + nexband
   ELSE
      numbands=nbnd-nexband
      nbtot=nbnd
   ENDIF
   nrtot = dffts%nr1*dffts%nr2*dffts%nr3
   info = 0
   minmn = MIN(numbands,nrtot)
   ALLOCATE(qr_tau(2*minmn))
#if defined(__SCALAPACK_QRCP)
   ! Dimensions of the process grid
   nprow = 1
   npcol = nproc
   ! Initialization of a default BLACS context and the processes grid
   call blacs_get( -1, 0, context )
   call blacs_gridinit( context, 'Row-major', nprow, npcol )
   call blacs_gridinfo( context, nprow, npcol, myrow, mycol )
   call descinit(descG, numbands, nrtot, minmn, minmn, 0, 0, context, max(1,minmn), info)
   ! Global blocks
   nblocks = nrtot / minmn
   rem = mod(nrtot, minmn)
   if (rem > 0) nblocks = nblocks + 1
   ! Local blocks
   nblocks_loc = nblocks / nproc
   rem_loc = mod(nblocks, nproc)
   if (mpime < rem_loc) nblocks_loc = nblocks_loc + 1
   ALLOCATE(piv_p(minmn*nblocks_loc))
   piv_p(:) = 0
   ALLOCATE(psi_gamma(minmn*nblocks_loc,minmn))
#else
   ALLOCATE(piv(nrtot))
   piv(:) = 0
   ALLOCATE(rwork(2*nrtot))
   rwork(:) = 0.0_DP
   ALLOCATE(psi_gamma(nrtot,numbands))
#endif
   ALLOCATE(kpt_latt(3,iknum))
   ALLOCATE(nowfc1(n_wannier,numbands))
   ALLOCATE(nowfc(n_wannier,numbands))
   ALLOCATE(focc(numbands))
   minmn2 = MIN(numbands,n_wannier)
   maxmn2 = MAX(numbands,n_wannier)
   ALLOCATE(rwork2(5*minmn2))

   ALLOCATE(rpos(nrtot,3))
   ALLOCATE(cpos(n_wannier,3))
   ALLOCATE(phase(n_wannier))
   ALLOCATE(singval(n_wannier))
   ALLOCATE(Umat(numbands,n_wannier))
   ALLOCATE(VTmat(n_wannier,n_wannier))
   ALLOCATE(Amat(numbands,n_wannier))

   IF (wan_mode=='library') ALLOCATE(a_mat(num_bands,n_wannier,iknum))

   IF (wan_mode=='standalone') THEN
      iun_amn = find_free_unit()
      IF (ionode) OPEN (unit=iun_amn, file=trim(seedname)//".amn",form='formatted')
   ENDIF

   WRITE(stdout,'(a,i8)') '  AMN: iknum = ',iknum
   !
   IF (wan_mode=='standalone') THEN
      CALL date_and_tim( cdate, ctime )
      header='Created on '//cdate//' at '//ctime//' with SCDM '
      IF (ionode) THEN
         WRITE (iun_amn,*) header
         WRITE (iun_amn,'(3i8,xxx,2f10.6)') numbands,  iknum, n_wannier, scdm_mu, scdm_sigma
      ENDIF
   ENDIF

   !vv: Find Gamma-point index in the list of k-vectors
   ik  = 0
   gamma_idx = 1
   sumk = -1.0_DP
   found_gamma = .false.
   kpt_latt(:,1:iknum)=xk(:,1:iknum)
   CALL cryst_to_cart(iknum,kpt_latt,at,-1)
   DO WHILE(sumk/=0.0_DP .and. ik < iknum)
      ik = ik + 1
      sumk = ABS(kpt_latt(1,ik)**2 + kpt_latt(2,ik)**2 + kpt_latt(3,ik)**2)
      IF (sumk==0.0_DP) THEN
         found_gamma = .true.
         gamma_idx = ik
      ENDIF
   END DO
   IF (.not. found_gamma) call errore('compute_amn','No Gamma point found.',1)

   f_gamma = 0.0_DP
   ik = gamma_idx
   locibnd = 0
   CALL davcio (evc, 2*nwordwfc, iunwfc, ik, -1 )
   DO ibnd=1,nbtot
      IF(excluded_band(ibnd)) CYCLE
      locibnd = locibnd + 1
      ! check locibnd <= numbands
      IF (locibnd > numbands) call errore('compute_amn','Something wrong with the number of bands. Check exclude_bands.')
      IF(TRIM(scdm_entanglement) == 'isolated') THEN
         f_gamma = 1.0_DP
      ELSEIF (TRIM(scdm_entanglement) == 'erfc') THEN
         f_gamma = 0.5_DP*ERFC((et(ibnd,ik)*rytoev - scdm_mu)/scdm_sigma)
      ELSEIF (TRIM(scdm_entanglement) == 'gaussian') THEN
         f_gamma = EXP(-1.0_DP*((et(ibnd,ik)*rytoev - scdm_mu)**2)/(scdm_sigma**2))
      ELSE
         call errore('compute_amn','scdm_entanglement value not recognized.',1)
      END IF
      npw = ngk(ik)
      ! vv: Compute unk's on a real grid (the fft grid)
      psic(:) = (0.D0,0.D0)
      psic(dffts%nl (igk_k (1:npw,ik) ) ) = evc (1:npw,ibnd)
      CALL invfft ('Wave', psic, dffts)
#if defined(__MPI)
      CALL gather_grid(dffts,psic,psic_all)
      ! vv: Gamma only
      ! vv: Build Psi_k = Unk * focc
#if defined(__SCALAPACK_QRCP)
      CALL mp_bcast(psic_all,ionode_id,world_comm)
      norm_psi = sqrt(real(sum(psic_all(1:nrtot)*conjg(psic_all(1:nrtot))),kind=DP))
      do ibl=0,nblocks_loc-1
        psi_gamma(minmn*ibl+1:minmn*(ibl+1),locibnd) = &
            psic_all(minmn*(ibl*nproc+mpime)+1:minmn*(ibl*nproc+mpime+1)) * (f_gamma / norm_psi)
      enddo
#else
      norm_psi = sqrt(real(sum(psic_all(1:nrtot)*conjg(psic_all(1:nrtot))),kind=DP))
      ! need to bcast to all processors to avoid division-by-zero
      CALL mp_bcast(norm_psi, ionode_id, world_comm)
      psic_all(1:nrtot) = psic_all(1:nrtot)/ norm_psi
      psi_gamma(1:nrtot,locibnd) = psic_all(1:nrtot)
      psi_gamma(1:nrtot,locibnd) = psi_gamma(1:nrtot,locibnd) * f_gamma
#endif
#else
      norm_psi = sqrt(real(sum(psic(1:nrtot)*conjg(psic(1:nrtot))),kind=DP))
      psic(1:nrtot) = psic(1:nrtot)/ norm_psi
      psi_gamma(1:nrtot,locibnd) = psic(1:nrtot)
      psi_gamma(1:nrtot,locibnd) = psi_gamma(1:nrtot,locibnd) * f_gamma
#endif
   ENDDO

   ! vv: Perform QR factorization with pivoting on Psi_Gamma
#if defined(__SCALAPACK_QRCP)
   WRITE(stdout, '(5x,A,I4,A)') "Running QRCP in parallel, using ", nproc, " cores"
   call PZGEQPF( numbands, nrtot, psi_gamma, 1, 1, descG, piv_p, qr_tau, &
                 tmp_cwork, -1, tmp_rwork, -1, info )

   lcwork = AINT(REAL(tmp_cwork(1)))
   lrwork = AINT(REAL(tmp_rwork(1)))
   ALLOCATE(rwork(lrwork))
   ALLOCATE(cwork(lcwork))
   rwork(:) = 0.0
   cwork(:) = cmplx(0.0,0.0)

   call PZGEQPF( numbands, nrtot, TRANSPOSE(CONJG(psi_gamma)), 1, 1, descG, piv_p, qr_tau, &
                 cwork, lcwork, rwork, lrwork, info )

   ALLOCATE(piv(minmn))
   if (ionode) piv(1:minmn) = piv_p(1:minmn)
   CALL mp_bcast(piv(1:minmn),ionode_id,world_comm)
   DEALLOCATE(piv_p)
#else
   WRITE(stdout, '(5x, "Running QRCP in serial")')
#if defined(__SCALAPACK)
   WRITE(stdout, '(10x, A)') "Program compiled with ScaLAPACK but not using it for QRCP."
   WRITE(stdout, '(10x, A)') "To enable ScaLAPACK for QRCP, use valid versions"
   WRITE(stdout, '(10x, A)') "(ScaLAPACK >= 2.1.0 or MKL >= 2020) and set the argument"
   WRITE(stdout, '(10x, A)') "'with-scalapack_version' in configure."
#endif
   ! vv: Preliminary call to define optimal values for lwork and cwork size
   CALL ZGEQP3(numbands,nrtot,TRANSPOSE(CONJG(psi_gamma)),numbands,piv,qr_tau,tmp_cwork,-1,rwork,info)
   IF(info/=0) call errore('compute_amn','Error in computing the QR factorization',1)
   lcwork = AINT(REAL(tmp_cwork(1)))
   tmp_cwork(:) = (0.0_DP,0.0_DP)
   piv(:) = 0
   rwork(:) = 0.0_DP
   ALLOCATE(cwork(lcwork))
   cwork(:) = (0.0_DP,0.0_DP)
#if defined(__MPI)
   IF(ionode) THEN
      CALL ZGEQP3(numbands,nrtot,TRANSPOSE(CONJG(psi_gamma)),numbands,piv,qr_tau,cwork,lcwork,rwork,info)
      IF(info/=0) call errore('compute_amn','Error in computing the QR factorization',1)
   ENDIF
   CALL mp_bcast(piv,ionode_id,world_comm)
#else
   ! vv: Perform QR factorization with pivoting on Psi_Gamma
   CALL ZGEQP3(numbands,nrtot,TRANSPOSE(CONJG(psi_gamma)),numbands,piv,qr_tau,cwork,lcwork,rwork,info)
   IF(info/=0) call errore('compute_amn','Error in computing the QR factorization',1)
#endif
#endif
   DEALLOCATE(cwork)
   tmp_cwork(:) = (0.0_DP,0.0_DP)

   ! vv: Compute the points
   lpt = 0
   rpos(:,:) = 0.0_DP
   cpos(:,:) = 0.0_DP
   DO kpt = 0,dffts%nr3-1
      DO jpt = 0,dffts%nr2-1
         DO ipt = 0,dffts%nr1-1
            lpt = lpt + 1
            rpos(lpt,1) = REAL(ipt, DP) / REAL(dffts%nr1, DP)
            rpos(lpt,2) = REAL(jpt, DP) / REAL(dffts%nr2, DP)
            rpos(lpt,3) = REAL(kpt, DP) / REAL(dffts%nr3, DP)
         ENDDO
      ENDDO
   ENDDO
   DO iw=1,n_wannier
      cpos(iw,:) = rpos(piv(iw),:)
      cpos(iw,:) = cpos(iw,:) - ANINT(cpos(iw,:))
   ENDDO

   DO ik=1,iknum
      WRITE (stdout,'(i8)',advance='no') ik
      IF( MOD(ik,10) == 0 ) WRITE (stdout,*)
      FLUSH(stdout)
      ikevc = ik + ikstart - 1

      ! vv: SCDM method for generating the Amn matrix
      ! jml: calculate of psi_nk at pivot points using slow FT
      !      This is faster than using invfft because the number of pivot
      !      points is much smaller than the number of FFT grid points.
      phase(:) = (0.0_DP,0.0_DP)
      nowfc1(:,:) = (0.0_DP,0.0_DP)
      nowfc(:,:) = (0.0_DP,0.0_DP)
      Umat(:,:) = (0.0_DP,0.0_DP)
      VTmat(:,:) = (0.0_DP,0.0_DP)
      Amat(:,:) = (0.0_DP,0.0_DP)
      singval(:) = 0.0_DP
      rwork2(:) = 0.0_DP

      ! jml: calculate phase factors before the loop over bands
      npw = ngk(ik)
      ALLOCATE(phase_g(npw, n_wannier))
      DO iw = 1, n_wannier
        phase(iw) = cmplx(COS(2.0_DP*pi*(cpos(iw,1)*kpt_latt(1,ik) + &
                   &cpos(iw,2)*kpt_latt(2,ik) + cpos(iw,3)*kpt_latt(3,ik))), &    !*ddot(3,cpos(iw,:),1,kpt_latt(:,ik),1)),&
                   &SIN(2.0_DP*pi*(cpos(iw,1)*kpt_latt(1,ik) + &
                   &cpos(iw,2)*kpt_latt(2,ik) + cpos(iw,3)*kpt_latt(3,ik))),kind=DP) !ddot(3,cpos(iw,:),1,kpt_latt(:,ik),1)))

        DO ig_local = 1, npw
          ig = igk_k(ig_local,ik)
          tpi_r_dot_g = 2.0_DP * pi * ( cpos(iw,1) * REAL(mill(1,ig), DP) &
                                    & + cpos(iw,2) * REAL(mill(2,ig), DP) &
                                    & + cpos(iw,3) * REAL(mill(3,ig), DP) )
          phase_g(ig_local, iw) = cmplx(COS(tpi_r_dot_g), SIN(tpi_r_dot_g), kind=DP)
        END DO
      END DO

      locibnd = 0
      CALL davcio (evc, 2*nwordwfc, iunwfc, ikevc, -1 )
      ! vv: Generate the occupation numbers matrix according to scdm_entanglement
      DO ibnd=1,nbtot
         IF (excluded_band(ibnd)) CYCLE
         locibnd = locibnd + 1
         ! vv: Define the occupation numbers matrix according to scdm_entanglement
         IF(TRIM(scdm_entanglement) == 'isolated') THEN
            focc(locibnd) = 1.0_DP
         ELSEIF (TRIM(scdm_entanglement) == 'erfc') THEN
            focc(locibnd) = 0.5_DP*ERFC((et(ibnd,ik)*rytoev - scdm_mu)/scdm_sigma)
         ELSEIF (TRIM(scdm_entanglement) == 'gaussian') THEN
            focc(locibnd) = EXP(-1.0_DP*((et(ibnd,ik)*rytoev - scdm_mu)**2)/(scdm_sigma**2))
         ELSE
            call errore('compute_amn','scdm_entanglement value not recognized.',1)
         END IF

         norm_psi = REAL(SUM( evc(1:npw, ibnd) * CONJG(evc(1:npw, ibnd)) ))
         CALL mp_sum(norm_psi, intra_pool_comm)
         norm_psi = SQRT(norm_psi)

         ! jml: nowfc = sum_G (psi(G) * exp(i*G*r)) * focc  * phase(iw) / norm_psi
         DO iw = 1, n_wannier
            nowfc_tmp = SUM( evc(1:npw, ibnd) * phase_g(1:npw, iw) )
            nowfc(iw,locibnd) = nowfc_tmp * phase(iw) * focc(locibnd) / norm_psi
         ENDDO

      ENDDO
      CALL mp_sum(nowfc, intra_pool_comm) ! jml
      DEALLOCATE(phase_g) ! jml

      CALL ZGESVD('S','S',numbands,n_wannier,TRANSPOSE(CONJG(nowfc)),numbands,&
           &singval,Umat,numbands,VTmat,n_wannier,tmp_cwork,-1,rwork2,info)
      lcwork = AINT(REAL(tmp_cwork(1)))
      tmp_cwork(:) = (0.0_DP,0.0_DP)
      ALLOCATE(cwork(lcwork))
#if defined(__MPI)
     IF(ionode) THEN
     ! vv: SVD to generate orthogonal projections
     CALL ZGESVD('S','S',numbands,n_wannier,TRANSPOSE(CONJG(nowfc)),numbands,&
          &singval,Umat,numbands,VTmat,n_wannier,cwork,lcwork,rwork2,info)
        IF(info/=0) CALL errore('compute_amn','Error in computing the SVD of the PSI matrix in the SCDM method',1)
     ENDIF
     CALL mp_bcast(Umat,ionode_id,world_comm)
     CALL mp_bcast(VTmat,ionode_id,world_comm)
#else
      ! vv: SVD to generate orthogonal projections
      CALL ZGESVD('S','S',numbands,n_wannier,TRANSPOSE(CONJG(nowfc)),numbands,&
           &singval,Umat,numbands,VTmat,n_wannier,cwork,lcwork,rwork2,info)
      IF(info/=0) CALL errore('compute_amn','Error in computing the SVD of the PSI matrix in the SCDM method',1)
#endif
      DEALLOCATE(cwork)

      Amat = MATMUL(Umat,VTmat)
      DO iw = 1,n_wannier
         locibnd = 0
         DO ibnd = 1,nbtot
            IF (excluded_band(ibnd)) CYCLE
            locibnd = locibnd + 1
            IF (ionode) WRITE(iun_amn,'(3i5,2f18.12)') locibnd, iw, ik, REAL(Amat(locibnd,iw)), AIMAG(Amat(locibnd,iw))
         ENDDO
      ENDDO
   ENDDO  ! k-points

   ! vv: Deallocate all the variables for the SCDM method
   DEALLOCATE(kpt_latt)
   DEALLOCATE(psi_gamma)
   DEALLOCATE(nowfc)
   DEALLOCATE(nowfc1)
   DEALLOCATE(focc)
   DEALLOCATE(piv)
   DEALLOCATE(qr_tau)
   DEALLOCATE(rwork)
   DEALLOCATE(rwork2)
   DEALLOCATE(rpos)
   DEALLOCATE(cpos)
   DEALLOCATE(Umat)
   DEALLOCATE(VTmat)
   DEALLOCATE(Amat)
   DEALLOCATE(singval)

#if defined(__MPI)
   DEALLOCATE( psic_all )
#endif

#if defined(__SCALAPACK_QRCP)
   ! Close BLACS environment
   call blacs_gridexit( context )
   call blacs_exit( 1 )
#endif

   IF (ionode .and. wan_mode=='standalone') CLOSE (iun_amn)
   WRITE(stdout,'(/)')
   WRITE(stdout,*) ' AMN calculated'
   CALL stop_clock( 'compute_amn' )

   RETURN
END SUBROUTINE compute_amn_with_scdm


SUBROUTINE compute_amn_with_scdm_spinor
   !
   ! jml: scdm for noncollinear case
   !
   USE constants,       ONLY : rytoev, pi
   USE io_global,       ONLY : stdout, ionode, ionode_id
   USE wvfct,           ONLY : nbnd, et, npwx
   USE gvecw,           ONLY : gcutw
   USE control_flags,   ONLY : gamma_only
   USE wavefunctions,   ONLY : evc, psic_nc
   USE io_files,        ONLY : nwordwfc, iunwfc
   USE wannier
   USE klist,           ONLY : nkstot, xk, ngk, igk_k
   USE gvect,           ONLY : g, ngm, mill
   USE fft_base,        ONLY : dffts !vv: unk for the SCDM-k algorithm
   USE scatter_mod,     ONLY : gather_grid
   USE fft_interfaces,  ONLY : invfft !vv: inverse fft transform for computing the unk's on a grid
   USE noncollin_module,ONLY : noncolin, npol
   USE mp,              ONLY : mp_bcast, mp_barrier, mp_sum
   USE mp_world,        ONLY : world_comm
   USE mp_pools,        ONLY : intra_pool_comm
   USE cell_base,       ONLY : at
   USE ions_base,       ONLY : ntyp => nsp, tau
   USE uspp_param,      ONLY : upf

   IMPLICIT NONE

   INTEGER, EXTERNAL :: find_free_unit
   COMPLEX(DP), ALLOCATABLE :: phase(:), nowfc1(:,:), nowfc(:,:), psi_gamma(:,:), &
       qr_tau(:), cwork(:), cwork2(:), Umat(:,:), VTmat(:,:), Amat(:,:) ! vv: complex arrays for the SVD factorization
   COMPLEX(DP), ALLOCATABLE :: phase_g(:,:) ! jml
   REAL(DP), ALLOCATABLE :: focc(:), rwork(:), rwork2(:), singval(:), rpos(:,:), cpos(:,:) ! vv: Real array for the QR factorization and SVD
   INTEGER, ALLOCATABLE :: piv(:) ! vv: Pivot array in the QR factorization
   INTEGER, ALLOCATABLE :: piv_pos(:), piv_spin(:) ! jml: position and spin index of piv
   COMPLEX(DP) :: tmp_cwork(2)
   COMPLEX(DP) :: nowfc_tmp ! jml
   REAL(DP):: ddot, sumk, norm_psi, f_gamma, tpi_r_dot_g
   INTEGER :: ik, npw, ibnd, iw, ikevc, nrtot, ipt, info, lcwork, locibnd, &
              jpt,kpt,lpt, ib, istart, gamma_idx, minmn, minmn2, maxmn2, numbands, nbtot, &
              ig, ig_local, count_piv_spin, ispin ! jml
   CHARACTER (len=9)  :: cdate,ctime
   CHARACTER (len=header_len) :: header
   LOGICAL            :: any_uspp, found_gamma

#if defined(__MPI)
   INTEGER :: nxxs
   COMPLEX(DP),ALLOCATABLE :: psic_all(:,:)
   nxxs = dffts%nr1x * dffts%nr2x * dffts%nr3x
   ALLOCATE(psic_all(nxxs, 2) )
#endif

   ! vv: Write info about SCDM in output
   IF (TRIM(scdm_entanglement) == 'isolated') THEN
      WRITE(stdout,'(1x,a,a/)') 'Case  : ',trim(scdm_entanglement)
   ELSEIF (TRIM(scdm_entanglement) == 'erfc' .OR. &
        TRIM(scdm_entanglement) == 'gaussian') THEN
      WRITE(stdout,'(1x,a,a)') 'Case  : ',trim(scdm_entanglement)
      WRITE(stdout,'(1x,a,f10.3,a/,1x,a,f10.3,a/)') 'mu    = ', scdm_mu, ' eV', 'sigma =', scdm_sigma, ' eV'
   ENDIF

   CALL start_clock( 'compute_amn' )

   any_uspp =any (upf(1:ntyp)%tvanp)

   ! vv: Error for using SCDM with Ultrasoft pseudopotentials
   !IF (any_uspp) THEN
   !   call errore('pw2wannier90','The SCDM method does not work with Ultrasoft pseudopotential yet.',1)
   !ENDIF

   ! vv: Error for using SCDM with gamma_only
   IF (gamma_only) THEN
      call errore('pw2wannier90','The SCDM method does not work with gamma_only calculations.',1)
   ENDIF
   ! vv: Allocate all the variables for the SCDM method:
   !     1)For the QR decomposition
   !     2)For the unk's on the real grid
   !     3)For the SVD
   IF(TRIM(scdm_entanglement) == 'isolated') THEN
      numbands=n_wannier
      nbtot=n_wannier + nexband
   ELSE
      numbands=nbnd-nexband
      nbtot=nbnd
   ENDIF
   nrtot = dffts%nr1*dffts%nr2*dffts%nr3
   info = 0
   minmn = MIN(numbands,nrtot*2) ! jml: spinor
   ALLOCATE(qr_tau(2*minmn))
   ALLOCATE(piv(nrtot*2)) ! jml: spinor
   ALLOCATE(piv_pos(n_wannier)) ! jml: spinor
   ALLOCATE(piv_spin(n_wannier)) ! jml: spinor
   piv(:) = 0
   ALLOCATE(rwork(2*nrtot*2)) ! jml: spinor
   rwork(:) = 0.0_DP

   ALLOCATE(kpt_latt(3,iknum))
   ALLOCATE(nowfc1(n_wannier,numbands))
   ALLOCATE(nowfc(n_wannier,numbands))
   ALLOCATE(psi_gamma(nrtot*2,numbands)) ! jml: spinor
   ALLOCATE(focc(numbands))
   minmn2 = MIN(numbands,n_wannier)
   maxmn2 = MAX(numbands,n_wannier)
   ALLOCATE(rwork2(5*minmn2))

   ALLOCATE(rpos(nrtot,3)) ! jml: spinor
   ALLOCATE(cpos(n_wannier,3))
   ALLOCATE(phase(n_wannier))
   ALLOCATE(singval(n_wannier))
   ALLOCATE(Umat(numbands,n_wannier))
   ALLOCATE(VTmat(n_wannier,n_wannier))
   ALLOCATE(Amat(numbands,n_wannier))

   IF (wan_mode=='library') ALLOCATE(a_mat(num_bands,n_wannier,iknum))

   IF (wan_mode=='standalone') THEN
      iun_amn = find_free_unit()
      IF (ionode) OPEN (unit=iun_amn, file=trim(seedname)//".amn",form='formatted')
   ENDIF

   WRITE(stdout,'(a,i8)') '  AMN: iknum = ',iknum
   !
   IF (wan_mode=='standalone') THEN
      CALL date_and_tim( cdate, ctime )
      header='Created on '//cdate//' at '//ctime//' with SCDM '
      IF (ionode) THEN
         WRITE (iun_amn,*) header
         WRITE (iun_amn,'(3i8,xxx,2f10.6)') numbands,  iknum, n_wannier, scdm_mu, scdm_sigma
      ENDIF
   ENDIF

   !vv: Find Gamma-point index in the list of k-vectors
   ik  = 0
   gamma_idx = 1
   sumk = -1.0_DP
   found_gamma = .false.
   kpt_latt(:,1:iknum)=xk(:,1:iknum)
   CALL cryst_to_cart(iknum,kpt_latt,at,-1)
   DO WHILE(sumk/=0.0_DP .and. ik < iknum)
      ik = ik + 1
      sumk = ABS(kpt_latt(1,ik)**2 + kpt_latt(2,ik)**2 + kpt_latt(3,ik)**2)
      IF (sumk==0.0_DP) THEN
         found_gamma = .true.
         gamma_idx = ik
      ENDIF
   END DO
   IF (.not. found_gamma) call errore('compute_amn','No Gamma point found.',1)

   f_gamma = 0.0_DP
   ik = gamma_idx
   locibnd = 0
   CALL davcio (evc, 2*nwordwfc, iunwfc, ik, -1 )
   DO ibnd=1,nbtot
      IF(excluded_band(ibnd)) CYCLE
      locibnd = locibnd + 1
      ! check locibnd <= numbands
      IF (locibnd > numbands) call errore('compute_amn','Something wrong with the number of bands. Check exclude_bands.')
      IF(TRIM(scdm_entanglement) == 'isolated') THEN
         f_gamma = 1.0_DP
      ELSEIF (TRIM(scdm_entanglement) == 'erfc') THEN
         f_gamma = 0.5_DP*ERFC((et(ibnd,ik)*rytoev - scdm_mu)/scdm_sigma)
      ELSEIF (TRIM(scdm_entanglement) == 'gaussian') THEN
         f_gamma = EXP(-1.0_DP*((et(ibnd,ik)*rytoev - scdm_mu)**2)/(scdm_sigma**2))
      ELSE
         call errore('compute_amn','scdm_entanglement value not recognized.',1)
      END IF
      npw = ngk(ik)
      ! vv: Compute unk's on a real grid (the fft grid)
      psic_nc(:,:) = (0.D0,0.D0)
      psic_nc(dffts%nl (igk_k (1:npw,ik) ), 1) = evc (1:npw,ibnd)
      psic_nc(dffts%nl (igk_k (1:npw,ik) ), 2) = evc (1+npwx:npw+npwx,ibnd)
      CALL invfft ('Wave', psic_nc(:,1), dffts)
      CALL invfft ('Wave', psic_nc(:,2), dffts)

#if defined(__MPI)
      CALL gather_grid(dffts, psic_nc(:,1), psic_all(:,1))
      CALL gather_grid(dffts, psic_nc(:,2), psic_all(:,2))
      norm_psi = sqrt( real(sum(psic_all(1:nrtot, 1)*conjg(psic_all(1:nrtot, 1))),kind=DP) &
                      +real(sum(psic_all(1:nrtot, 2)*conjg(psic_all(1:nrtot, 2))),kind=DP) )
      CALL mp_bcast(norm_psi, ionode_id, world_comm)
      ! vv: Gamma only
      ! vv: Build Psi_k = Unk * focc
      psi_gamma(1:nrtot,        locibnd) = psic_all(1:nrtot, 1) * f_gamma / norm_psi
      psi_gamma(1+nrtot:2*nrtot,locibnd) = psic_all(1:nrtot, 2) * f_gamma / norm_psi
#else
      norm_psi = sqrt( real(sum(psic_nc(1:nrtot, 1)*conjg(psic_nc(1:nrtot, 1))),kind=DP) &
                      +real(sum(psic_nc(1:nrtot, 2)*conjg(psic_nc(1:nrtot, 2))),kind=DP) )
      psi_gamma(1:nrtot,        locibnd) = psic_nc(1:nrtot, 1) * f_gamma / norm_psi
      psi_gamma(1+nrtot:2*nrtot,locibnd) = psic_nc(1:nrtot, 2) * f_gamma / norm_psi
#endif
   ENDDO

   ! vv: Perform QR factorization with pivoting on Psi_Gamma
   ! vv: Preliminary call to define optimal values for lwork and cwork size
   CALL ZGEQP3(numbands,nrtot*2,TRANSPOSE(CONJG(psi_gamma)),numbands,piv,qr_tau,tmp_cwork,-1,rwork,info)
   IF(info/=0) call errore('compute_amn','Error in computing the QR factorization',1)
   lcwork = AINT(REAL(tmp_cwork(1)))
   tmp_cwork(:) = (0.0_DP,0.0_DP)
   piv(:) = 0
   rwork(:) = 0.0_DP
   ALLOCATE(cwork(lcwork))
   cwork(:) = (0.0_DP,0.0_DP)
#if defined(__MPI)
   IF(ionode) THEN
      CALL ZGEQP3(numbands,nrtot*2,TRANSPOSE(CONJG(psi_gamma)),numbands,piv,qr_tau,cwork,lcwork,rwork,info)
      IF(info/=0) call errore('compute_amn','Error in computing the QR factorization',1)
   ENDIF
   CALL mp_bcast(piv,ionode_id,world_comm)
#else
   ! vv: Perform QR factorization with pivoting on Psi_Gamma
   CALL ZGEQP3(numbands,nrtot*2,TRANSPOSE(CONJG(psi_gamma)),numbands,piv,qr_tau,cwork,lcwork,rwork,info)
   IF(info/=0) call errore('compute_amn','Error in computing the QR factorization',1)
#endif
   DEALLOCATE(cwork)
   tmp_cwork(:) = (0.0_DP,0.0_DP)

   ! jml: calculate position and spin part of piv
   count_piv_spin = 0
   DO iw = 1, n_wannier
     IF (piv(iw) .le. nrtot) then
       piv_pos(iw) = piv(iw)
       piv_spin(iw) = 1
       count_piv_spin = count_piv_spin + 1
     else
       piv_pos(iw) = piv(iw) - nrtot
       piv_spin(iw) = 2
     end if
   END DO
   WRITE(stdout, '(a,I5)') " Number of pivot points with spin up  : ", count_piv_spin
   WRITE(stdout, '(a,I5)') " Number of pivot points with spin down: ", n_wannier - count_piv_spin

   ! vv: Compute the points
   lpt = 0
   rpos(:,:) = 0.0_DP
   cpos(:,:) = 0.0_DP
   DO kpt = 0,dffts%nr3-1
      DO jpt = 0,dffts%nr2-1
         DO ipt = 0,dffts%nr1-1
            lpt = lpt + 1
            rpos(lpt,1) = DBLE(ipt)/DBLE(dffts%nr1)
            rpos(lpt,2) = DBLE(jpt)/DBLE(dffts%nr2)
            rpos(lpt,3) = DBLE(kpt)/DBLE(dffts%nr3)
         ENDDO
      ENDDO
   ENDDO
   DO iw=1,n_wannier
      cpos(iw,:) = rpos(piv_pos(iw),:)
      cpos(iw,:) = cpos(iw,:) - ANINT(cpos(iw,:))
   ENDDO

   DO ik=1,iknum
      WRITE (stdout,'(i8)',advance='no') ik
      IF( MOD(ik,10) == 0 ) WRITE (stdout,*)
      FLUSH(stdout)
      ikevc = ik + ikstart - 1

      ! vv: SCDM method for generating the Amn matrix
      ! jml: calculate of psi_nk at pivot points using slow FT
      !      This is faster than using invfft because the number of pivot
      !      points is much smaller than the number of FFT grid points.
      phase(:) = (0.0_DP,0.0_DP)
      nowfc1(:,:) = (0.0_DP,0.0_DP)
      nowfc(:,:) = (0.0_DP,0.0_DP)
      Umat(:,:) = (0.0_DP,0.0_DP)
      VTmat(:,:) = (0.0_DP,0.0_DP)
      Amat(:,:) = (0.0_DP,0.0_DP)
      singval(:) = 0.0_DP
      rwork2(:) = 0.0_DP

      ! jml: calculate phase factors before the loop over bands
      npw = ngk(ik)
      ALLOCATE(phase_g(npw, n_wannier))
      DO iw = 1, n_wannier
        phase(iw) = cmplx(COS(2.0_DP*pi*(cpos(iw,1)*kpt_latt(1,ik) + &
                   &cpos(iw,2)*kpt_latt(2,ik) + cpos(iw,3)*kpt_latt(3,ik))), &    !*ddot(3,cpos(iw,:),1,kpt_latt(:,ik),1)),&
                   &SIN(2.0_DP*pi*(cpos(iw,1)*kpt_latt(1,ik) + &
                   &cpos(iw,2)*kpt_latt(2,ik) + cpos(iw,3)*kpt_latt(3,ik))),kind=DP) !ddot(3,cpos(iw,:),1,kpt_latt(:,ik),1)))

        DO ig_local = 1, npw
          ig = igk_k(ig_local,ik)
          tpi_r_dot_g = 2.0_DP * pi * ( cpos(iw,1) * REAL(mill(1,ig), DP) &
                                    & + cpos(iw,2) * REAL(mill(2,ig), DP) &
                                    & + cpos(iw,3) * REAL(mill(3,ig), DP) )
          phase_g(ig_local, iw) = cmplx(COS(tpi_r_dot_g), SIN(tpi_r_dot_g), kind=DP)
        END DO
      END DO

      locibnd = 0
      CALL davcio (evc, 2*nwordwfc, iunwfc, ikevc, -1 )
      DO ibnd=1,nbtot
         IF (excluded_band(ibnd)) CYCLE
         locibnd = locibnd + 1
         ! vv: Define the occupation numbers matrix according to scdm_entanglement
         IF(TRIM(scdm_entanglement) == 'isolated') THEN
            focc(locibnd) = 1.0_DP
         ELSEIF (TRIM(scdm_entanglement) == 'erfc') THEN
            focc(locibnd) = 0.5_DP*ERFC((et(ibnd,ik)*rytoev - scdm_mu)/scdm_sigma)
         ELSEIF (TRIM(scdm_entanglement) == 'gaussian') THEN
            focc(locibnd) = EXP(-1.0_DP*((et(ibnd,ik)*rytoev - scdm_mu)**2)/(scdm_sigma**2))
         ELSE
            call errore('compute_amn','scdm_entanglement value not recognized.',1)
         END IF

         norm_psi= REAL(SUM( evc(1:npw,ibnd) * CONJG(evc(1:npw,ibnd)) )) &
              + REAL(SUM( evc(1+npwx:npw+npwx,ibnd) * CONJG(evc(1+npwx:npw+npwx,ibnd)) ))
         CALL mp_sum(norm_psi, intra_pool_comm)
         norm_psi= sqrt(norm_psi)

         ! jml: nowfc = sum_G (psi(G) * exp(i*G*r)) * focc  * phase(iw) / norm_psi
         DO iw = 1, n_wannier
           if (piv_spin(iw) == 1) then ! spin up
             nowfc_tmp = sum( evc(1:npw, ibnd) * phase_g(1:npw, iw) )
           else ! spin down
             nowfc_tmp = sum( evc(1+npwx:npw+npwx, ibnd) * phase_g(1:npw, iw) )
           end if

           nowfc(iw, locibnd) = nowfc_tmp * phase(iw) * focc(locibnd) / norm_psi
         ENDDO

       END DO ! ibnd
       CALL mp_sum(nowfc, intra_pool_comm) ! jml
       DEALLOCATE(phase_g) ! jml

      CALL ZGESVD('S','S',numbands,n_wannier,TRANSPOSE(CONJG(nowfc)),numbands,&
           &singval,Umat,numbands,VTmat,n_wannier,tmp_cwork,-1,rwork2,info)
      lcwork = AINT(REAL(tmp_cwork(1)))
      tmp_cwork(:) = (0.0_DP,0.0_DP)
      ALLOCATE(cwork(lcwork))
#if defined(__MPI)
     IF(ionode) THEN
     ! vv: SVD to generate orthogonal projections
     CALL ZGESVD('S','S',numbands,n_wannier,TRANSPOSE(CONJG(nowfc)),numbands,&
          &singval,Umat,numbands,VTmat,n_wannier,cwork,lcwork,rwork2,info)
        IF(info/=0) CALL errore('compute_amn','Error in computing the SVD of the PSI matrix in the SCDM method',1)
     ENDIF
     CALL mp_bcast(Umat,ionode_id,world_comm)
     CALL mp_bcast(VTmat,ionode_id,world_comm)
#else
      ! vv: SVD to generate orthogonal projections
      CALL ZGESVD('S','S',numbands,n_wannier,TRANSPOSE(CONJG(nowfc)),numbands,&
           &singval,Umat,numbands,VTmat,n_wannier,cwork,lcwork,rwork2,info)
      IF(info/=0) CALL errore('compute_amn','Error in computing the SVD of the PSI matrix in the SCDM method',1)
#endif
      DEALLOCATE(cwork)

      Amat = MATMUL(Umat,VTmat)

      CALL start_clock( 'scdm_write' )
      DO iw = 1,n_wannier
         locibnd = 0
         DO ibnd = 1,nbtot
            IF (excluded_band(ibnd)) CYCLE
            locibnd = locibnd + 1
            IF (ionode) WRITE(iun_amn,'(3i5,2f18.12)') locibnd, iw, ik, REAL(Amat(locibnd,iw)), AIMAG(Amat(locibnd,iw))
         ENDDO
      ENDDO
      CALL stop_clock( 'scdm_write' )
   ENDDO  ! k-points

   ! vv: Deallocate all the variables for the SCDM method
   DEALLOCATE(kpt_latt)
   DEALLOCATE(psi_gamma)
   DEALLOCATE(nowfc)
   DEALLOCATE(nowfc1)
   DEALLOCATE(focc)
   DEALLOCATE(piv)
   DEALLOCATE(piv_pos)
   DEALLOCATE(piv_spin)
   DEALLOCATE(qr_tau)
   DEALLOCATE(rwork)
   DEALLOCATE(rwork2)
   DEALLOCATE(rpos)
   DEALLOCATE(cpos)
   DEALLOCATE(Umat)
   DEALLOCATE(VTmat)
   DEALLOCATE(Amat)
   DEALLOCATE(singval)

#if defined(__MPI)
   DEALLOCATE( psic_all )
#endif

   IF (ionode .and. wan_mode=='standalone') CLOSE (iun_amn)
   WRITE(stdout,'(/)')
   WRITE(stdout,*) ' AMN calculated'
   CALL stop_clock( 'compute_amn' )

   RETURN
END SUBROUTINE compute_amn_with_scdm_spinor

SUBROUTINE compute_amn_with_atomproj
  ! Use internal UPF atomic projectors or external projectors
  ! to compute amn matrices.
  !
  ! The code is roughly the same as projwfc.x with some entensions:
  ! 1. allow using external projectors (i.e. custom radial functions)
  ! 2. allow skipping orthogonalization of projectors
  ! 3. allow excluding projectors specified by user
  ! 4. allow excluding bands specified by user
  !
  USE kinds, ONLY: DP
  USE io_global, ONLY: stdout, ionode, ionode_id
  USE ions_base, ONLY: nat, ityp, atm, nsp
  USE basis, ONLY: natomwfc, swfcatom
  USE klist, ONLY: xk, nks, nkstot, nelec, ngk, igk_k
  USE lsda_mod, ONLY: nspin
  USE noncollin_module, ONLY: noncolin, npol, lspinorb, domag
  USE wvfct, ONLY: npwx, nbnd
  USE uspp, ONLY: nkb, vkb
  USE uspp_init, ONLY : init_us_2
  USE becmod, ONLY: bec_type, becp, calbec, allocate_bec_type, deallocate_bec_type
  USE io_files, ONLY: prefix, restart_dir, tmp_dir
  USE control_flags, ONLY: gamma_only, use_para_diag
  USE pw_restart_new, ONLY: read_collected_wfc
  USE wavefunctions, ONLY: evc
  !
  USE projections, ONLY: nlmchi, fill_nlmchi, compute_mj, &
                         sym_proj_g, sym_proj_k, sym_proj_nc, sym_proj_so, &
                         compute_zdistmat, compute_ddistmat, &
                         wf_times_overlap, wf_times_roverlap
  !
  USE mp, ONLY: mp_bcast
  USE mp_pools, ONLY: me_pool, root_pool, intra_pool_comm
  USE mp_world, ONLY: world_comm
  USE wannier
  USE atproj, ONLY: atom_proj_dir, atom_proj_ext, atom_proj_ortho, &
                    atom_proj_sym, natproj, nexatproj, nexatproj_max, &
                    atproj_excl, atproj_typs, &
                    atom_proj_exclude, write_file_amn, &
                    allocate_atproj_type, read_atomproj, init_tab_atproj, &
                    deallocate_atproj, atomproj_wfc
  !
  IMPLICIT NONE
  !
  INCLUDE 'laxlib.fh'
  !
  INTEGER :: npw, npw_, ik, ibnd, nwfc, lmax_wfc
  INTEGER :: i, j, k, it, l, m
  REAL(DP), ALLOCATABLE :: e(:)
  COMPLEX(DP), ALLOCATABLE :: wfcatom(:, :), wfcatomall(:, :)
  COMPLEX(DP), ALLOCATABLE :: proj0(:, :), proj0all(:, :), proj(:, :, :)
  COMPLEX(DP), ALLOCATABLE :: e_work_d(:, :)
  ! Some workspace for gamma-point calculation ...
  REAL(DP), ALLOCATABLE :: rproj0(:, :), rproj0all(:, :)
  COMPLEX(DP), ALLOCATABLE :: overlap_d(:, :), work_d(:, :), diag(:, :), vv(:, :)
  REAL(DP), ALLOCATABLE :: roverlap_d(:, :)
  !
  LOGICAL :: freeswfcatom
  !
  INTEGER :: idesc(LAX_DESC_SIZE)
  INTEGER, ALLOCATABLE :: idesc_ip(:, :, :)
  INTEGER, ALLOCATABLE :: rank_ip(:, :)
  ! matrix distribution descriptors
  INTEGER :: nx, nrl, nrlx
  ! maximum local block dimension
  LOGICAL :: la_proc
  ! flag to distinguish procs involved in linear algebra
  INTEGER, ALLOCATABLE :: notcnv_ip(:)
  INTEGER, ALLOCATABLE :: ic_notcnv(:)
  LOGICAL :: do_distr_diag_inside_bgrp
  INTEGER :: nproc_ortho
  ! distinguishes active procs in parallel linear algebra
  CHARACTER(len=256) :: err_str
  LOGICAL :: has_excl_proj
  INTEGER :: ierr

  CALL start_clock('compute_amn')

  IF (wan_mode == 'library') THEN
    CALL errore('pw2wannier90', 'have not tested with library mode', 1)
  END IF

  IF (atom_proj_ext) THEN
    if (domag) &
      CALL errore('pw2wannier90', &
                  'does not support magnetism with external projectors', 1)

    if (noncolin) &
      CALL errore('pw2wannier90', &
                  'does not support non-collinear magnetism with external projectors', 1)

    IF (atom_proj_sym) &
      CALL errore('pw2wannier90', &
                  'does not support symmetrization with external projectors', 1)
  END IF

  IF (atom_proj_ext) THEN
    ALLOCATE (atproj_typs(nsp), stat=ierr)
    IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating atproj_typs', 1)
  END IF

  IF (ionode) THEN
    IF (atom_proj_ext) THEN
      WRITE (stdout, '(a)') '  Using atomic projectors from dir '//TRIM(atom_proj_dir)
      WRITE (stdout, *) ''

      CALL read_atomproj(atproj_typs)

      n_proj = 0
      DO i = 1, nat
        it = ityp(i)
        DO nwfc = 1, atproj_typs(it)%nproj
          l = atproj_typs(it)%l(nwfc)
          DO m = 1, 2*l+1
            n_proj = n_proj + 1
            WRITE (stdout, 1000, ADVANCE="no") &
              n_proj, i, atproj_typs(it)%atsym, nwfc, l
            WRITE (stdout, 1003) m
          END DO
        END DO
      END DO
      WRITE (stdout, *) ''
    ELSE
      WRITE (stdout, '(a)') '  Use atomic projectors from UPF'
      WRITE (stdout, *) ''
      WRITE (stdout, '( 5x,"(read from pseudopotential files):"/)')
      CALL fill_nlmchi(natomwfc, lmax_wfc)
      DO nwfc = 1, natomwfc
        WRITE (stdout, 1000, ADVANCE="no") &
          nwfc, nlmchi(nwfc)%na, atm(ityp(nlmchi(nwfc)%na)), &
          nlmchi(nwfc)%n, nlmchi(nwfc)%l
        IF (lspinorb) THEN
          WRITE (stdout, 1001) nlmchi(nwfc)%jj, &
            compute_mj(nlmchi(nwfc)%jj, nlmchi(nwfc)%l, nlmchi(nwfc)%m)
        ELSE IF (noncolin) THEN
          WRITE (stdout, 1002) nlmchi(nwfc)%m, &
            0.5D0 - INT(nlmchi(nwfc)%ind/(2*nlmchi(nwfc)%l + 2))
        ELSE
          WRITE (stdout, 1003) nlmchi(nwfc)%m
        END IF
      END DO
      WRITE (stdout, *) ''
      n_proj = natomwfc
    END IF
1000  FORMAT(5X, "state #", i4, ": atom ", i3, " (", a3, "), wfc ", i2, &
             " (l=", i1)
1001  FORMAT(" j=", f3.1, " m_j=", f4.1, ")")
1002  FORMAT(" m=", i2, " s_z=", f4.1, ")")
1003  FORMAT(" m=", i2, ")")

    IF (n_proj <= 0) CALL errore('pw2wannier90', &
                                 'Cannot project on zero atomic projectors!', 1)

    ! check exclude
    allocate(atproj_excl(n_proj), stat=ierr)
    IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating atproj_excl', 1)
    atproj_excl = .false.

    DO i = 1, nexatproj_max
      IF (atom_proj_exclude(i) > n_proj) THEN
        WRITE (err_str, *) 'atom_proj_exclude(', i, ') = ', &
          atom_proj_exclude(i), &
          '> total number of projectors (', n_proj, ')'
        CALL errore('pw2wannier90', err_str, i)
      else if (atom_proj_exclude(i) < 0) then
        CYCLE
      else
        atproj_excl(atom_proj_exclude(i)) = .true.
      END IF
    END DO

    nexatproj = COUNT(atproj_excl)
    IF (nexatproj > 0) THEN
      has_excl_proj = .TRUE.
    ELSE
      has_excl_proj = .FALSE.
    END IF

    natproj = n_proj

    IF (has_excl_proj) THEN
      WRITE (stdout, *) '    excluded projectors: '
      j = 0 ! how many elements have been written
      DO i = 1, n_proj
        if (atproj_excl(i)) THEN
          WRITE (stdout, '(i8)', advance='no') i
          j = j + 1
          IF (MOD(j, 10) == 0) WRITE (stdout, *)
        END IF
      END DO
      WRITE (stdout, *) ''
      n_proj = n_proj - nexatproj
    END IF

    IF (gamma_only) &
      WRITE (stdout, '(5x,"gamma-point specific algorithms are used")')

    FLUSH (stdout)
  END IF

  ! MPI related calls
  IF (atom_proj_ext) THEN
    DO it = 1, nsp
      i = atproj_typs(it)%ngrid
      j = atproj_typs(it)%nproj
      call mp_bcast(i, ionode_id, world_comm)
      call mp_bcast(j, ionode_id, world_comm)
      if (.NOT. ionode) &
        call allocate_atproj_type(atproj_typs(it), i, j)

      CALL mp_bcast(atproj_typs(it)%atsym, ionode_id, world_comm)
      CALL mp_bcast(atproj_typs(it)%xgrid, ionode_id, world_comm)
      CALL mp_bcast(atproj_typs(it)%rgrid, ionode_id, world_comm)
      CALL mp_bcast(atproj_typs(it)%l, ionode_id, world_comm)
      CALL mp_bcast(atproj_typs(it)%radial, ionode_id, world_comm)
    END DO

    call init_tab_atproj(world_comm)
  ELSE
    ! need to access nlmchi, natomwfc, lmax_wfc on each core,
    ! the root node has been filled already
    IF (.NOT. ionode) CALL fill_nlmchi(natomwfc, lmax_wfc)
  END IF
  CALL mp_bcast(natproj, ionode_id, world_comm)
  CALL mp_bcast(n_proj, ionode_id, world_comm)
  CALL mp_bcast(nexatproj, ionode_id, world_comm)
  CALL mp_bcast(has_excl_proj, ionode_id, world_comm)
  if (.not. ionode) then
     allocate(atproj_excl(n_proj+nexatproj), stat=ierr)
     IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating atproj_excl', 1)
  end if
  CALL mp_bcast(atproj_excl, ionode_id, world_comm)
  !
  !   Initialize parallelism for linear algebra
  !
  CALL set_para_diag(n_proj, use_para_diag)
  !
  CALL desc_init(n_proj, nx, la_proc, idesc, rank_ip, idesc_ip)
  CALL laxlib_getval(nproc_ortho=nproc_ortho)
  use_para_diag = (nproc_ortho > 1)
  IF (ionode .AND. use_para_diag) THEN
    WRITE (stdout, &
           '(5x,"linear algebra parallelized on ",i3," procs")') nproc_ortho
  END IF
  !
  IF (ionode) THEN
    !
    !   nbnd = num_bands + nexband
    ! For UPF projectors:
    !   natomwfc = n_proj + nexatproj
    !
    WRITE (stdout, *)
    WRITE (stdout, *) '    Problem Sizes '
    WRITE (stdout, *) '      n_proj    = ', n_proj
    IF (atom_proj_ext) THEN
      WRITE (stdout, *) '      natproj   = ', natproj
    ELSE
      WRITE (stdout, *) '      natomwfc  = ', natomwfc
    END IF
    WRITE (stdout, *) '      num_bands = ', num_bands
    WRITE (stdout, *) '      nbnd      = ', nbnd
    WRITE (stdout, *) '      nkstot    = ', nkstot
    IF (use_para_diag) WRITE (stdout, *) '      nx        = ', nx
    WRITE (stdout, *) '      npwx      = ', npwx
    WRITE (stdout, *) '      nkb       = ', nkb
    WRITE (stdout, *)
  END IF
  !
  ALLOCATE (proj(num_bands, n_proj, nkstot))
  !
  IF (.NOT. ALLOCATED(swfcatom)) THEN
    ALLOCATE (swfcatom(npwx*npol, n_proj), stat=ierr)
    IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating swfcatom', 1)
    freeswfcatom = .TRUE.
  ELSE
    freeswfcatom = .FALSE.
  END IF

  ALLOCATE (wfcatom(npwx*npol, n_proj), stat=ierr)
  IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating wfcatom', 1)
  IF (has_excl_proj) THEN
    ! additional space for excluded projectors, for atomic_wfc(), etc.
    IF (atom_proj_ext) THEN
      ALLOCATE (wfcatomall(npwx*npol, natproj), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating wfcatomall', 1)
    ELSE
      ALLOCATE (wfcatomall(npwx*npol, natomwfc), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating wfcatomall', 1)
   END IF
  END IF
  ALLOCATE (e(n_proj), stat=ierr)
  IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating e', 1)
  !
  !    loop on k points
  !
  WRITE (stdout, '(a,i8)') '  AMN: iknum = ', iknum
  DO ik = 1, nks
    !
    IF (ionode) THEN
      WRITE (stdout, '(i8)', advance='no') ik
      IF (MOD(ik, 10) == 0) WRITE (stdout, *)
      FLUSH (stdout)
    END IF
    !
    npw = ngk(ik)
    CALL read_collected_wfc(restart_dir(), ik, evc)
    !
    ! exclude bands
    IF (nexband > 0) THEN
      i = 1
      DO j = 1, nbnd
        IF (excluded_band(j)) CYCLE
        IF (i /= j) evc(:, i) = evc(:, j)
        i = i + 1
      END DO
      evc(:, (num_bands + 1):nbnd) = (0.0_DP, 0.0_DP)
    END IF
    !
    wfcatom(:, :) = (0.0_DP, 0.0_DP)
    IF (atom_proj_ext) THEN
      IF (.NOT. has_excl_proj) THEN
        CALL atomproj_wfc(ik, wfcatom)
      ELSE
        wfcatomall(:, :) = (0.0_DP, 0.0_DP)
        CALL atomproj_wfc(ik, wfcatomall)
        ! exclude projectors
        i = 1 ! counter for wfcatom
        DO j = 1, natproj ! counter for wfcatomall
          IF (atproj_excl(j)) CYCLE
          wfcatom(:, i) = wfcatomall(:, j)
          i = i + 1
        END DO
        IF ((i - 1) /= n_proj) THEN
          CALL errore('compute_amn_with_atomproj', &
                      'internal error when excluding projectors', i)
        END IF
      END IF
    ELSE
      IF (.NOT. has_excl_proj) THEN
        IF (noncolin) THEN
          CALL atomic_wfc_nc_proj(ik, wfcatom)
        ELSE
          CALL atomic_wfc(ik, wfcatom)
        END IF
      ELSE
        wfcatomall(:, :) = (0.0_DP, 0.0_DP)
        IF (noncolin) THEN
          CALL atomic_wfc_nc_proj(ik, wfcatomall)
        ELSE
          CALL atomic_wfc(ik, wfcatomall)
        END IF
        ! exclude projectors
        i = 1 ! counter for wfcatom
        DO j = 1, natomwfc ! counter for wfcatomall
          IF (atproj_excl(j)) CYCLE
          wfcatom(:, i) = wfcatomall(:, j)
          i = i + 1
        END DO
        IF ((i - 1) /= n_proj) THEN
          CALL errore('compute_amn_with_atomproj', &
                      'internal error when excluding projectors', i)
        END IF
      END IF
    END IF
    !
    CALL allocate_bec_type(nkb, n_proj, becp)
    !
    CALL init_us_2(npw, igk_k(1, ik), xk(1, ik), vkb)
    CALL calbec(npw, vkb, wfcatom, becp)
    CALL s_psi(npwx, npw, n_proj, wfcatom, swfcatom)
    !
    CALL deallocate_bec_type(becp)
    !
    ! wfcatom = |phi_i> , swfcatom = \hat S |phi_i>
    ! calculate overlap matrix O_ij = <phi_i|\hat S|\phi_j>
    !
    IF (atom_proj_ortho) THEN
      IF (la_proc) THEN
        ALLOCATE (overlap_d(nx, nx), stat=ierr)
        IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating overlap_d', 1)
      ELSE
        ALLOCATE (overlap_d(1, 1), stat=ierr)
        IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating overlap_d', 1)
      END IF
      overlap_d = (0.D0, 0.D0)
      npw_ = npw
      IF (noncolin) npw_ = npol*npwx
      IF (gamma_only) THEN
        !
        ! in the Gamma-only case the overlap matrix (real) is copied
        ! to a complex one as for the general case - easy but wasteful
        !
        IF (la_proc) THEN
          ALLOCATE (roverlap_d(nx, nx), stat=ierr)
          IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating roverlap_d', 1)
        ELSE
          ALLOCATE (roverlap_d(1, 1), stat=ierr)
          IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating roverlap_d', 1)
        END IF
        roverlap_d = 0.D0
        CALL compute_ddistmat(npw, n_proj, nx, wfcatom, swfcatom, roverlap_d, &
                              idesc, rank_ip, idesc_ip)
        overlap_d(:, :) = CMPLX(roverlap_d(:, :), 0.0_DP, kind=dp)
      ELSE
        CALL compute_zdistmat(npw_, n_proj, nx, wfcatom, swfcatom, overlap_d, &
                              idesc, rank_ip, idesc_ip)
      END IF
      !
      ! diagonalize the overlap matrix
      !
      IF (la_proc) THEN
        !
        ALLOCATE (work_d(nx, nx), stat=ierr)
        IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating work_d', 1)

        nrl = idesc(LAX_DESC_NRL)
        nrlx = idesc(LAX_DESC_NRLX)

        ALLOCATE (diag(nrlx, n_proj), stat=ierr)
        IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating diag', 1)
        ALLOCATE (vv(nrlx, n_proj), stat=ierr)
        IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating vv', 1)
        !
        !  re-distribute the overlap matrix for parallel diagonalization
        !
        CALL blk2cyc_redist(n_proj, diag, nrlx, n_proj, overlap_d, nx, nx, idesc)
        !
        ! parallel diagonalization
        !
        CALL zhpev_drv('V', diag, nrlx, e, vv, nrlx, nrl, n_proj, &
                       idesc(LAX_DESC_NPC)*idesc(LAX_DESC_NPR), &
                       idesc(LAX_DESC_MYPE), idesc(LAX_DESC_COMM))
        !
        !  bring distributed eigenvectors back to original distribution
        !
        CALL cyc2blk_redist(n_proj, vv, nrlx, n_proj, work_d, nx, nx, idesc)
        !
        DEALLOCATE (vv)
        DEALLOCATE (diag)
        !
      ELSE
        ALLOCATE (work_d(1, 1), stat=ierr)
        IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating work_d', 1)
      END IF

      CALL mp_bcast(e, root_pool, intra_pool_comm)

      ! calculate O^{-1/2} (actually, its transpose)

      DO i = 1, n_proj
        e(i) = 1.D0/dsqrt(e(i))
      END DO

      IF (la_proc) THEN
        ALLOCATE (e_work_d(nx, nx), stat=ierr)
        IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating e_work_d', 1)
        DO j = 1, idesc(LAX_DESC_NC)
          DO i = 1, idesc(LAX_DESC_NR)
            e_work_d(i, j) = e(j + idesc(LAX_DESC_IC) - 1)*work_d(i, j)
          END DO
        END DO
        CALL sqr_mm_cannon('N', 'C', n_proj, (1.0_DP, 0.0_DP), e_work_d, &
                           nx, work_d, nx, (0.0_DP, 0.0_DP), overlap_d, nx, idesc)
        CALL laxlib_zsqmher(n_proj, overlap_d, nx, idesc)
        DEALLOCATE (e_work_d)
      END IF
      !
      DEALLOCATE (work_d)
      !
      ! calculate wfcatom = O^{-1/2} \hat S | phi>
      !
      IF (gamma_only) THEN
        roverlap_d(:, :) = REAL(overlap_d(:, :), DP)
        CALL wf_times_roverlap(nx, npw, swfcatom, roverlap_d, wfcatom, &
                               idesc, rank_ip, idesc_ip, la_proc)
        DEALLOCATE (roverlap_d)
      ELSE
        CALL wf_times_overlap(nx, npw_, swfcatom, overlap_d, wfcatom, &
                              idesc, rank_ip, idesc_ip, la_proc)
      END IF
      DEALLOCATE (overlap_d)
    END IF
    !
    ! make the projection <psi_i| O^{-1/2} \hat S | phi_j>,
    ! symmetrize the projections if required
    !
    IF (gamma_only) THEN
      !
      ALLOCATE (rproj0(n_proj, num_bands), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating rproj0', 1)
      CALL calbec(npw, wfcatom, evc, rproj0, nbnd=num_bands)
      ! haven't tested symmetrization with external projectors, so
      ! I disable these for now.
      ! IF ((.NOT. atom_proj_ext) .AND. atom_proj_sym) THEN
      !   IF (has_excl_proj) THEN
      !     ALLOCATE (rproj0all(natomwfc, num_bands))
      !     rproj0all = 0.0_DP
      !     ! expand the size to natomwfc so I can call sym_proj_g
      !     ! the excluded part is just 0.0
      !     i = 1 ! counter for rproj0
      !     DO j = 1, natomwfc ! counter for rproj0all
      !       IF (atproj_excl(j)) CYCLE
      !       rproj0all(j, :) = rproj0(i, :)
      !       i = i + 1
      !     END DO
      !     !
      !     CALL sym_proj_g(rproj0all)
      !     !
      !     ! exclude projectors
      !     i = 1 ! counter for rproj0
      !     DO j = 1, natomwfc ! counter for rproj0all
      !       IF (atproj_excl(j)) CYCLE
      !       rproj0(i, :) = rproj0all(j, :)
      !       i = i + 1
      !     END DO
      !     !
      !     DEALLOCATE (rproj0all)
      !   ELSE
      !     CALL sym_proj_g(rproj0)
      !   END IF
      ! END IF

      ! Note the CONJG, I need <psi|g>, while rpoj0 = <g|psi>
      proj(:, :, ik) = TRANSPOSE(rproj0(:, :))
      DEALLOCATE (rproj0)
      !
   ELSE
      !
      ALLOCATE (proj0(n_proj, num_bands), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating proj0', 1)
      CALL calbec(npw_, wfcatom, evc, proj0, nbnd=num_bands)
      !
      ! IF ((.NOT. atom_proj_ext) .AND. atom_proj_sym) THEN
      !   IF (has_excl_proj) THEN
      !     ALLOCATE (proj0all(natomwfc, num_bands))
      !     proj0all = (0.0_DP, 0.0_DP)
      !     ! expand the size to natomwfc so I can call sym_proj_*
      !     ! the exclude part is just 0.0
      !     i = 1 ! counter for proj0
      !     DO j = 1, natomwfc ! counter for proj0all
      !       IF (atproj_excl(j)) CYCLE
      !       proj0all(j, :) = proj0(i, :)
      !       i = i + 1
      !     END DO
      !     !
      !     IF (lspinorb) THEN
      !       CALL sym_proj_so(domag, proj0all)
      !     ELSE IF (noncolin) THEN
      !       CALL sym_proj_nc(proj0all)
      !     ELSE
      !       CALL sym_proj_k(proj0all)
      !     END IF
      !     !
      !     ! exclude projectors
      !     i = 1 ! counter for proj0
      !     DO j = 1, natomwfc ! counter for proj0all
      !       IF (atproj_excl(j)) CYCLE
      !       proj0(i, :) = proj0all(j, :)
      !       i = i + 1
      !     END DO
      !     !
      !     DEALLOCATE (proj0all)
      !   ELSE
      !     IF (lspinorb) THEN
      !       CALL sym_proj_so(domag, proj0)
      !     ELSE IF (noncolin) THEN
      !       CALL sym_proj_nc(proj0)
      !     ELSE
      !       CALL sym_proj_k(proj0)
      !     END IF
      !   END IF
      ! END IF

      ! Note the CONJG, I need <psi|g>, while proj0 = <g|psi>
      proj(:, :, ik) = TRANSPOSE(CONJG(proj0(:, :)))
      DEALLOCATE (proj0)
      !
   END IF
  END DO ! on k-points
  !
  call deallocate_atproj()
  DEALLOCATE (e)
  DEALLOCATE (wfcatom)
  IF (freeswfcatom) DEALLOCATE (swfcatom)
  IF (has_excl_proj) THEN
    DEALLOCATE (wfcatomall)
  END IF
  DEALLOCATE (idesc_ip)
  DEALLOCATE (rank_ip)
  !
  !   vector proj are distributed across the pools
  !   collect data for all k-points to the first pool
  !
  CALL poolrecover(proj, 2*num_bands*n_proj, nkstot, nks)
  !
  ! write to standard output and to file
  !
  IF (ionode) THEN
    CALL write_file_amn(proj)
    !
    WRITE (stdout, '(/)')
    WRITE (stdout, *) ' AMN calculated'
  END IF
  !
  DEALLOCATE (proj)
  CALL laxlib_end()

  CALL stop_clock('compute_amn')

  RETURN

END SUBROUTINE compute_amn_with_atomproj

subroutine orient_gf_spinor(npw)
   use constants, only: eps6
   use noncollin_module, only: npol
   use wvfct,           ONLY : npwx
   use wannier

   implicit none

   integer :: npw, iw, ipol, istart, iw_spinor
   logical :: spin_z_pos, spin_z_neg
   complex(dp) :: fac(2)


   gf_spinor = (0.0d0, 0.0d0)
   if (old_spinor_proj) then
      iw_spinor = 1
      DO ipol=1,npol
        istart = (ipol-1)*npwx + 1
        DO iw = 1,n_proj
          ! generate 2*nproj spinor functions, one for each spin channel
          gf_spinor(istart:istart+npw-1, iw_spinor) = gf(1:npw, iw)
          iw_spinor = iw_spinor + 1
        enddo
      enddo
   else
     DO iw = 1,n_proj
        spin_z_pos=.false.;spin_z_neg=.false.
        ! detect if spin quantisation axis is along z
        if((abs(spin_qaxis(1,iw)-0.0d0)<eps6).and.(abs(spin_qaxis(2,iw)-0.0d0)<eps6) &
           .and.(abs(spin_qaxis(3,iw)-1.0d0)<eps6)) then
           spin_z_pos=.true.
        elseif(abs(spin_qaxis(1,iw)-0.0d0)<eps6.and.abs(spin_qaxis(2,iw)-0.0d0)<eps6 &
           .and.abs(spin_qaxis(3,iw)+1.0d0)<eps6) then
           spin_z_neg=.true.
        endif
        if(spin_z_pos .or. spin_z_neg) then
           if(spin_z_pos) then
              ipol=(3-spin_eig(iw))/2
           else
              ipol=(3+spin_eig(iw))/2
           endif
           istart = (ipol-1)*npwx + 1
           gf_spinor(istart:istart+npw-1, iw) = gf(1:npw, iw)
        else
          if(spin_eig(iw)==1) then
             fac(1)=(1.0_dp/sqrt(1+spin_qaxis(3,iw)))*(spin_qaxis(3,iw)+1)*cmplx(1.0d0,0.0d0,dp)
             fac(2)=(1.0_dp/sqrt(1+spin_qaxis(3,iw)))*cmplx(spin_qaxis(1,iw),spin_qaxis(2,iw),dp)
          else
             fac(1)=(1.0_dp/sqrt(1+spin_qaxis(3,iw)))*(spin_qaxis(3,iw))*cmplx(1.0d0,0.0d0,dp)
             fac(2)=(1.0_dp/sqrt(1-spin_qaxis(3,iw)))*cmplx(spin_qaxis(1,iw),spin_qaxis(2,iw),dp)
          endif
          gf_spinor(1:npw, iw) = gf(1:npw, iw) * fac(1)
          gf_spinor(npwx + 1:npwx + npw, iw) = gf(1:npw, iw) * fac(2)
        endif
     enddo
   endif
end subroutine orient_gf_spinor
!
SUBROUTINE generate_guiding_functions(ik)
   !! gf should not be normalized at each k point because the atomic orbitals are
   !! not orthonormal so that their Bloch representation is not normalized.
   !
   USE io_global,  ONLY : stdout
   USE constants, ONLY : pi, tpi, fpi, eps8
   USE control_flags, ONLY : gamma_only
   USE gvect, ONLY : g, gstart
   USE cell_base,  ONLY : tpiba
   USE wannier
   USE klist,      ONLY : xk, ngk, igk_k
   USE cell_base, ONLY : bg
   USE mp, ONLY : mp_sum
   USE mp_pools,  ONLY : intra_pool_comm

   IMPLICIT NONE

   INTEGER, INTENT(in) :: ik
   INTEGER, PARAMETER :: lmax=3, lmax2=(lmax+1)**2
   INTEGER :: npw, iw, ig, bgtau(3), isph, l, mesh_r
   INTEGER :: lmax_iw, lm, ipol, n1, n2, n3, nr1, nr2, nr3, iig
   real(DP) :: arg, fac, alpha_w2, yy, alfa, ddot
   COMPLEX(DP) :: zdotc, kphase, lphase, gff, lph
   real(DP), ALLOCATABLE :: gk(:,:), qg(:), ylm(:,:), radial(:,:)
   COMPLEX(DP), ALLOCATABLE :: sk(:)
   !
   npw = ngk(ik)
   ALLOCATE( gk(3,npw), qg(npw), ylm(npw,lmax2), sk(npw), radial(npw,0:lmax) )
   !
   DO ig = 1, npw
      gk (1,ig) = xk(1, ik) + g(1, igk_k(ig,ik) )
      gk (2,ig) = xk(2, ik) + g(2, igk_k(ig,ik) )
      gk (3,ig) = xk(3, ik) + g(3, igk_k(ig,ik) )
      qg(ig) = gk(1, ig)**2 +  gk(2, ig)**2 + gk(3, ig)**2
   ENDDO

   CALL ylmr2 (lmax2, npw, gk, qg, ylm)
   ! define qg as the norm of (k+g) in a.u.
   qg(:) = sqrt(qg(:)) * tpiba

   DO iw = 1, n_proj
      !
      gf(:,iw) = (0.d0,0.d0)

      CALL radialpart(npw, qg, alpha_w(iw), r_w(iw), lmax, radial)

      DO lm = 1, lmax2
         IF ( abs(csph(lm,iw)) < eps8 ) CYCLE
         l = int (sqrt( lm-1.d0))
         lphase = (0.d0,-1.d0)**l
         !
         DO ig=1,npw
            gf(ig,iw) = gf(ig,iw) + csph(lm,iw) * ylm(ig,lm) * radial(ig,l) * lphase
         ENDDO !ig
      ENDDO ! lm
      DO ig=1,npw
         iig = igk_k(ig,ik)
         arg = ( gk(1,ig)*center_w(1,iw) + gk(2,ig)*center_w(2,iw) + &
                                           gk(3,ig)*center_w(3,iw) ) * tpi
         ! center_w are cartesian coordinates in units of alat
         sk(ig) = cmplx(cos(arg), -sin(arg) ,kind=DP)
         gf(ig,iw) = gf(ig,iw) * sk(ig)
      ENDDO
   ENDDO
   !
   DEALLOCATE ( gk, qg, ylm, sk, radial)
   RETURN
END SUBROUTINE generate_guiding_functions

SUBROUTINE write_band
   USE io_global,  ONLY : stdout, ionode
   USE wvfct, ONLY : nbnd, et
   USE klist, ONLY : nkstot
   USE constants, ONLY: rytoev
   USE wannier

   IMPLICIT NONE
   !
   INTEGER, EXTERNAL :: find_free_unit
   !
   INTEGER ik, ibnd, ibnd1, ikevc, ierr

   IF (wan_mode=='standalone') THEN
      iun_band = find_free_unit()
      IF (ionode) THEN
         IF (irr_bz) THEN
            OPEN (unit=iun_band, file=trim(seedname)//".ieig",form='formatted')
         ELSE
            OPEN (unit=iun_band, file=trim(seedname)//".eig",form='formatted')
         ENDIF
      ENDIF
   ENDIF

   IF (wan_mode=='library') THEN
      ALLOCATE(eigval(num_bands,iknum), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating eigval', 1)
      eigval = 0.0_dp
   END IF

   DO ik=ikstart,ikstop
      ikevc = ik - ikstart + 1
      ibnd1=0
      DO ibnd=1,nbnd
         IF (excluded_band(ibnd)) CYCLE
         ibnd1=ibnd1 + 1
         IF (wan_mode=='standalone') THEN
            IF (ionode) WRITE (iun_band,'(2i5,f18.12)') ibnd1, ikevc, et(ibnd,ik)*rytoev
         ELSEIF (wan_mode=='library') THEN
            eigval(ibnd1,ikevc) = et(ibnd,ik)*rytoev
         ELSE
            CALL errore('write_band',' value of wan_mode not recognised',1)
         ENDIF
      ENDDO
   ENDDO

   IF (wan_mode=='standalone') THEN
       IF (ionode) CLOSE (unit=iun_band)
   ENDIF

   RETURN
END SUBROUTINE write_band

SUBROUTINE write_plot
   USE io_global,  ONLY : stdout, ionode
   USE wvfct, ONLY : nbnd, npwx
   USE gvecw, ONLY : gcutw
   USE control_flags, ONLY : gamma_only
   USE wavefunctions, ONLY : evc, psic, psic_nc
   USE io_files, ONLY : nwordwfc, iunwfc
   USE wannier
   USE klist,           ONLY : nkstot, xk, ngk, igk_k
   USE gvect,           ONLY : g, ngm
   USE fft_base,        ONLY : dffts
   USE scatter_mod,     ONLY : gather_grid
   USE fft_interfaces,  ONLY : invfft
   USE noncollin_module,ONLY : noncolin, npol

   IMPLICIT NONE
   !
   INTEGER, EXTERNAL :: find_free_unit
   !
   INTEGER ik, npw, ibnd, ibnd1, ikevc, i1, j, spin, ierr
   CHARACTER*20 wfnname

   ! aam: 1/5/06: for writing smaller unk files
   INTEGER :: n1by2,n2by2,n3by2,i,k,idx,pos
   COMPLEX(DP),ALLOCATABLE :: psic_small(:), psic_nc_small(:,:)

   INTEGER ipol
   !-------------------------------------------!

#if defined(__MPI)
   INTEGER nxxs
   COMPLEX(DP),ALLOCATABLE :: psic_all(:), psic_nc_all(:,:)
   nxxs = dffts%nr1x * dffts%nr2x * dffts%nr3x
   IF (.NOT.noncolin) THEN
      ALLOCATE(psic_all(nxxs), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating psic_all', 1)
   ELSE
      ALLOCATE(psic_nc_all(nxxs, npol), stat=ierr)
      IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating psic_nc_all', 1)
   ENDIF
#endif

   CALL start_clock( 'write_unk' )

   IF (reduce_unk) THEN
      WRITE(stdout,'(3(a,i5))') 'nr1s = ',dffts%nr1,' nr2s = ',dffts%nr2,' nr3s = ',dffts%nr3
      n1by2=(dffts%nr1+1)/2
      n2by2=(dffts%nr2+1)/2
      n3by2=(dffts%nr3+1)/2
      WRITE(stdout,'(3(a,i5))') 'n1by2 = ',n1by2,' n2by2 = ',n2by2,' n3by2 = ',n3by2
      IF (.NOT.noncolin) THEN
         ALLOCATE(psic_small(n1by2*n2by2*n3by2), stat=ierr)
         IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating psic_small', 1)
         psic_small = (0.0_DP, 0.0_DP)
      ELSE
         ALLOCATE(psic_nc_small(n1by2*n2by2*n3by2,npol), stat=ierr)
         IF (ierr /= 0) CALL errore('pw2wannier90', 'Error allocating psic_nc_small', 1)
         psic_nc_small = (0.0_DP, 0.0_DP)
      ENDIF
   ENDIF

   WRITE(stdout,'(a,i8)') ' UNK: iknum = ',iknum

   DO ik=ikstart,ikstop

      WRITE (stdout,'(i8)',advance='no') ik
      IF( MOD(ik,10) == 0 ) WRITE (stdout,*)
      FLUSH(stdout)

      ikevc = ik - ikstart + 1

      iun_plot = find_free_unit()
      !write(wfnname,200) p,spin
      spin=ispinw
      IF(ispinw==0) spin=1
      IF (.NOT.noncolin) THEN
         WRITE(wfnname,200) ikevc, spin
      ELSE
         WRITE(wfnname,201) ikevc
      ENDIF
201   FORMAT ('UNK',i5.5,'.','NC')
200   FORMAT ('UNK',i5.5,'.',i1)

   IF (ionode) THEN
      IF(wvfn_formatted) THEN
         OPEN (unit=iun_plot, file=wfnname,form='formatted')
         IF (reduce_unk) THEN
            WRITE(iun_plot,*)  n1by2,n2by2,n3by2, ikevc, nbnd-nexband
         ELSE
            WRITE(iun_plot,*)  dffts%nr1,dffts%nr2,dffts%nr3,ikevc,nbnd-nexband
         ENDIF
      ELSE
         OPEN (unit=iun_plot, file=wfnname,form='unformatted')
         IF (reduce_unk) THEN
            WRITE(iun_plot)  n1by2,n2by2,n3by2, ikevc, nbnd-nexband
         ELSE
            WRITE(iun_plot)  dffts%nr1,dffts%nr2,dffts%nr3,ikevc,nbnd-nexband
         ENDIF
      ENDIF
   ENDIF

      CALL davcio (evc, 2*nwordwfc, iunwfc, ik, -1 )

      npw = ngk(ik)
      ibnd1 = 0
      DO ibnd=1,nbnd
         IF (excluded_band(ibnd)) CYCLE
         ibnd1=ibnd1 + 1
         IF (.NOT.noncolin) THEN
            psic(:) = (0.d0, 0.d0)
            psic(dffts%nl (igk_k (1:npw,ik) ) ) = evc (1:npw, ibnd)
            IF (gamma_only)  psic(dffts%nlm(igk_k(1:npw,ik))) = conjg(evc (1:npw, ibnd))
            CALL invfft ('Wave', psic, dffts)
         ELSE
            psic_nc(:,:) = (0.d0, 0.d0)
            DO ipol = 1, npol
               psic_nc(dffts%nl (igk_k (1:npw,ik) ), ipol) = evc (1+npwx*(ipol-1):npw+npwx*(ipol-1), ibnd)
               CALL invfft ('Wave', psic_nc(:,ipol), dffts)
            ENDDO
         ENDIF
         IF (reduce_unk) pos=0
#if defined(__MPI)
         IF (.NOT.noncolin) THEN
            CALL gather_grid(dffts,psic,psic_all)
         ELSE
            DO ipol = 1, npol
               CALL gather_grid(dffts,psic_nc(:,ipol),psic_nc_all(:,ipol))
            ENDDO
         ENDIF
         IF (reduce_unk) THEN
            DO k=1,dffts%nr3,2
               DO j=1,dffts%nr2,2
                  DO i=1,dffts%nr1,2
                     idx = (k-1)*dffts%nr2*dffts%nr1 + (j-1)*dffts%nr1 + i
                     pos=pos+1
                     IF (.NOT.noncolin) THEN
                        psic_small(pos) = psic_all(idx)
                     ELSE
                        DO ipol = 1, npol
                           psic_nc_small(pos,ipol) = psic_nc_all(idx,ipol)
                        ENDDO
                     ENDIF
                  ENDDO
               ENDDO
            ENDDO
         ENDIF
      IF (ionode) THEN
         IF(wvfn_formatted) THEN
            IF (reduce_unk) THEN
               IF (.NOT.noncolin) THEN
                  WRITE (iun_plot,'(2ES20.10)') (psic_small(j),j=1,n1by2*n2by2*n3by2)
               ELSE
                  DO ipol = 1, npol
                     WRITE (iun_plot,'(2ES20.10)') (psic_nc_small(j,ipol),j=1,n1by2*n2by2*n3by2)
                  ENDDO
               ENDIF
            ELSE
               IF (.NOT.noncolin) THEN
                  WRITE (iun_plot,'(2ES20.10)') (psic_all(j),j=1,dffts%nr1*dffts%nr2*dffts%nr3)
               ELSE
                  DO ipol = 1, npol
                     WRITE (iun_plot,'(2ES20.10)') (psic_nc_all(j,ipol),j=1,dffts%nr1*dffts%nr2*dffts%nr3)
                  ENDDO
               ENDIF
            ENDIF
         ELSE
            IF (reduce_unk) THEN
               IF (.NOT.noncolin) THEN
                  WRITE (iun_plot) (psic_small(j),j=1,n1by2*n2by2*n3by2)
               ELSE
                  DO ipol = 1, npol
                     WRITE (iun_plot) (psic_nc_small(j,ipol),j=1,n1by2*n2by2*n3by2)
                  ENDDO
               ENDIF
            ELSE
               IF (.NOT.noncolin) THEN
                  WRITE (iun_plot) (psic_all(j),j=1,dffts%nr1*dffts%nr2*dffts%nr3)
               ELSE
                  DO ipol = 1, npol
                     WRITE (iun_plot) (psic_nc_all(j,ipol),j=1,dffts%nr1*dffts%nr2*dffts%nr3)
                  ENDDO
               ENDIF
            ENDIF
         ENDIF
      ENDIF
#else
         IF (reduce_unk) THEN
            DO k=1,dffts%nr3,2
               DO j=1,dffts%nr2,2
                  DO i=1,dffts%nr1,2
                     idx = (k-1)*dffts%nr2*dffts%nr1 + (j-1)*dffts%nr1 + i
                     pos=pos+1
                     IF (.NOT.noncolin) THEN
                        psic_small(pos) = psic(idx)
                     ELSE
                        DO ipol = 1, npol
                           psic_nc_small(pos,ipol) = psic_nc(idx,ipol)
                        ENDDO
                     ENDIF
                  ENDDO
               ENDDO
            ENDDO
         ENDIF
         IF(wvfn_formatted) THEN
            IF (.NOT.noncolin) THEN
               IF (reduce_unk) THEN
                  WRITE (iun_plot,'(2ES20.10)') (psic_small(j),j=1,n1by2*n2by2*n3by2)
               ELSE
                  WRITE (iun_plot,'(2ES20.10)') (psic(j),j=1,dffts%nr1*dffts%nr2*dffts%nr3)
               ENDIF
            ELSE
               DO ipol = 1, npol
                  IF (reduce_unk) THEN
                     WRITE (iun_plot,'(2ES20.10)') (psic_nc_small(j,ipol),j=1,n1by2*n2by2*n3by2)
                  ELSE
                     WRITE (iun_plot,'(2ES20.10)') (psic_nc(j,ipol),j=1,dffts%nr1*dffts%nr2*dffts%nr3)
                  ENDIF
               ENDDO
            ENDIF
         ELSE
            IF (.NOT.noncolin) THEN
               IF (reduce_unk) THEN
                  WRITE (iun_plot) (psic_small(j),j=1,n1by2*n2by2*n3by2)
               ELSE
                  WRITE (iun_plot) (psic(j),j=1,dffts%nr1*dffts%nr2*dffts%nr3)
               ENDIF
            ELSE
               DO ipol = 1, npol
                  IF (reduce_unk) THEN
                     WRITE (iun_plot) (psic_nc_small(j,ipol),j=1,n1by2*n2by2*n3by2)
                  ELSE
                     WRITE (iun_plot) (psic_nc(j,ipol),j=1,dffts%nr1*dffts%nr2*dffts%nr3)
                  ENDIF
               ENDDO
            ENDIF
         ENDIF
#endif
      ENDDO !ibnd

      IF(ionode) CLOSE (unit=iun_plot)

   ENDDO  !ik

   IF (reduce_unk) THEN
      IF (.NOT.noncolin) THEN
         DEALLOCATE(psic_small)
      ELSE
         DEALLOCATE(psic_nc_small)
      ENDIF
   ENDIF

#if defined(__MPI)
   IF (.NOT.noncolin) THEN
      DEALLOCATE( psic_all )
   ELSE
      DEALLOCATE( psic_nc_all )
   ENDIF
#endif

   WRITE(stdout,'(/)')
   WRITE(stdout,*) ' UNK written'

   CALL stop_clock( 'write_unk' )

   RETURN
END SUBROUTINE write_plot

SUBROUTINE write_parity

   USE mp_pools,             ONLY : intra_pool_comm
   USE mp_world,             ONLY : mpime, nproc
   USE mp,                   ONLY : mp_sum
   USE io_global,            ONLY : stdout, ionode
   USE wvfct,                ONLY : nbnd
   USE gvecw,                ONLY : gcutw
   USE control_flags,        ONLY : gamma_only
   USE wavefunctions, ONLY : evc
   USE io_files,             ONLY : nwordwfc, iunwfc
   USE wannier
   USE klist,                ONLY : nkstot, xk, igk_k, ngk
   USE gvect,                ONLY : g, ngm
   USE cell_base,            ONLY : at
   USE constants,            ONLY : eps6
   USE lsda_mod,             ONLY : lsda, isk

   IMPLICIT NONE
   !
   INTEGER, EXTERNAL :: find_free_unit
   !
   INTEGER                      :: npw,ibnd,igv,kgamma,ik,i,ig_idx(32)
   INTEGER,DIMENSION(nproc)     :: num_G,displ

   real(kind=dp)                :: g_abc_1D(32),g_abc_gathered(3,32)
   real(kind=dp),ALLOCATABLE    :: g_abc(:,:),g_abc_pre_gather(:,:,:)
   COMPLEX(kind=dp),ALLOCATABLE :: evc_sub(:,:,:),evc_sub_gathered(:,:)
   COMPLEX(kind=dp)             :: evc_sub_1D(32)

   CALL start_clock( 'write_parity' )

   !
   ! getting the ik index corresponding to the Gamma point
   ! ... and the spin channel (fix due to N Poilvert, Feb 2011)
   !
   IF (.not. gamma_only) THEN
      DO ik=ikstart,ikstop
         IF ( (xk(1,ik) == 0.d0) .AND. (xk(2,ik) == 0.d0) .AND. (xk(3,ik) == 0.d0) &
              .AND. (ispinw == 0 .OR. isk(ik) == ispinw) ) THEN
            kgamma = ik
            EXIT
         ENDIF
         IF (ik == ikstop) CALL errore('write_parity',&
              ' parity calculation may only be performed at the gamma point',1)
      ENDDO
   ELSE
      ! NP: spin unpolarized or "up" component of spin
      IF (ispinw == 0 .or. ispinw == 1) THEN
         kgamma=1
      ELSE ! NP: "down" component
         kgamma=2
      ENDIF
   ENDIF
   !
   ! building the evc array corresponding to the Gamma point
   !
   CALL davcio (evc, 2*nwordwfc, iunwfc, kgamma, -1 )
   npw = ngk(kgamma)
   !
   ! opening the <seedname>.unkg file
   !
   iun_parity = find_free_unit()
   IF (ionode)  THEN
        OPEN (unit=iun_parity, file=trim(seedname)//".unkg",form='formatted')
        WRITE(stdout,*)"Finding the 32 unkg's per band required for parity signature."
   ENDIF
   !
   ! g_abc(:,ipw) are the coordinates of the ipw-th G vector in b1, b2, b3 basis,
   ! we compute them from g(:,ipw) by multiplying : transpose(at) with g(:,ipw)
   !
   ALLOCATE(g_abc(3,npw))
   DO igv=1,npw
       g_abc(:,igk_k(igv,kgamma))=matmul(transpose(at),g(:,igk_k(igv,kgamma)))
   ENDDO
   !
   ! Count and identify the G vectors we will be extracting for each
   ! cpu.
   !
   ig_idx=0
   num_G = 0
   DO igv=1,npw
       ! 0-th Order
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! 1
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       ! 1st Order
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! x
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! y
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 1.d0) <= eps6) ) THEN ! z
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       ! 2nd Order
       IF ( (abs(g_abc(1,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! x^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! xy
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) + 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! xy
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 1.d0) <= eps6) ) THEN ! xz
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) + 1.d0) <= eps6) ) THEN ! xz
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! y^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 1.d0) <= eps6) ) THEN ! yz
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) + 1.d0) <= eps6) ) THEN ! yz
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 2.d0) <= eps6) ) THEN ! z^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       ! 3rd Order
       IF ( (abs(g_abc(1,igv) - 3.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! x^3
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! x^2y
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) + 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! x^2y
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 1.d0) <= eps6) ) THEN ! x^2z
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) + 1.d0) <= eps6) ) THEN ! x^2z
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! xy^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) + 2.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! xy^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 1.d0) <= eps6) ) THEN ! xyz
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) + 1.d0) <= eps6) ) THEN ! xyz
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) + 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 1.d0) <= eps6) ) THEN ! xyz
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) + 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) + 1.d0) <= eps6) ) THEN ! xyz
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 2.d0) <= eps6) ) THEN ! xz^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) + 2.d0) <= eps6) ) THEN ! xz^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 3.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 0.d0) <= eps6) ) THEN ! y^3
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 1.d0) <= eps6) ) THEN ! y^2z
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 2.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) + 1.d0) <= eps6) ) THEN ! y^2z
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 2.d0) <= eps6) ) THEN ! yz^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and.&
            (abs(g_abc(2,igv) - 1.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) + 2.d0) <= eps6) ) THEN ! yz^2
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
       IF ( (abs(g_abc(1,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(2,igv) - 0.d0) <= eps6) .and. &
            (abs(g_abc(3,igv) - 3.d0) <= eps6) ) THEN ! z^3
           num_G(mpime+1) = num_G(mpime+1) + 1
           ig_idx(num_G(mpime+1))=igv
           CYCLE
       ENDIF
   ENDDO
   !
   ! Sum laterally across cpus num_G, so it contains
   ! the number of g_vectors on each node, and known to all cpus
   !
   CALL mp_sum(num_G, intra_pool_comm)

   IF (ionode) WRITE(iun_parity,*) sum(num_G)
   IF (sum(num_G) /= 32) CALL errore('write_parity', 'incorrect number of g-vectors extracted',1)
   IF (ionode) THEN
      WRITE(stdout,*)'     ...done'
      WRITE(stdout,*)'G-vector splitting:'
      DO i=1,nproc
         WRITE(stdout,*)' cpu: ',i-1,' number g-vectors: ',num_G(i)
      ENDDO
      WRITE(stdout,*)' Collecting g-vectors and writing to file'
   ENDIF

   !
   ! Define needed intermediate arrays
   !
   ALLOCATE(evc_sub(32,nbnd,nproc))
   ALLOCATE(evc_sub_gathered(32,nbnd))
   ALLOCATE(g_abc_pre_gather(3,32,nproc))
   !
   ! Initialise
   !
   evc_sub=(0.d0,0.d0)
   evc_sub_1D=(0.d0,0.d0)
   evc_sub_gathered=(0.d0,0.d0)
   g_abc_pre_gather=0
   g_abc_1D=0
   g_abc_gathered=0
   !
   ! Compute displacements needed for filling evc_sub
   !
   displ(1)=1
   IF (nproc > 1) THEN
       DO i=2,nproc
           displ(i)=displ(i-1)+num_G(i-1)
       ENDDO
   ENDIF
   !
   ! Fill evc_sub with required fourier component from each cpu dependent evc
   !
   DO i=1,num_G(mpime+1)
       evc_sub(i+displ(mpime+1)-1,:,mpime+1)=evc(ig_idx(i),:)
   ENDDO
   !
   ! g_abc_pre_gather(:,ipw,icpu) are the coordinates of the ipw-th G vector in b1, b2, b3 basis
   ! on icpu and stored sequencially, ready for a lateral mp_sum
   !
   DO igv=1,num_G(mpime+1)
       g_abc_pre_gather(:,igv+displ(mpime+1)-1,mpime+1) = &
            matmul(transpose(at),g(:,ig_idx(igk_k(igv,kgamma))))
   ENDDO
   !
   ! Gather evc_sub and  g_abc_pre_gather into common arrays to each cpu
   !
   DO ibnd=1,nbnd
      evc_sub_1D=evc_sub(:,ibnd,mpime+1)
      CALL mp_sum(evc_sub_1D, intra_pool_comm)
      evc_sub_gathered(:,ibnd)=evc_sub_1D
   ENDDO
   !
   DO i=1,3
       g_abc_1D=g_abc_pre_gather(i,:,mpime+1)
       CALL mp_sum(g_abc_1D, intra_pool_comm)
       g_abc_gathered(i,:)=g_abc_1D
   ENDDO
   !
   ! Write to file
   !
   DO ibnd=1,nbnd
      DO igv=1,32
         IF (ionode) WRITE(iun_parity,'(5i5,2f12.7)') ibnd, igv, nint(g_abc_gathered(1,igv)),&
                                                                 nint(g_abc_gathered(2,igv)),&
                                                                 nint(g_abc_gathered(3,igv)),&
                                                                 real(evc_sub_gathered(igv,ibnd)),&
                                                                aimag(evc_sub_gathered(igv,ibnd))
      ENDDO
   ENDDO
   WRITE(stdout,*)'     ...done'
   !
   IF (ionode) CLOSE(unit=iun_parity)
   !
   DEALLOCATE(evc_sub)
   DEALLOCATE(evc_sub_gathered)
   DEALLOCATE(g_abc_pre_gather)

   CALL stop_clock( 'write_parity' )

END SUBROUTINE write_parity


SUBROUTINE wan2sic

  USE io_global,  ONLY : stdout
  USE kinds, ONLY : DP
  USE io_files, ONLY : iunwfc, nwordwfc, nwordwann
  USE gvect, ONLY : g, ngm
  USE wavefunctions, ONLY : evc, psic
  USE wvfct, ONLY : nbnd, npwx
  USE gvecw, ONLY : gcutw
  USE klist, ONLY : nkstot, xk, wk, ngk
  USE wannier

  IMPLICIT NONE

  INTEGER :: i, j, nn, ik, ibnd, iw, ikevc, npw
  COMPLEX(DP), ALLOCATABLE :: orbital(:,:), u_matrix(:,:,:)
  INTEGER :: iunatsicwfc = 31 ! unit for sic wfc

  OPEN (20, file = trim(seedname)//".dat" , form = 'formatted', status = 'unknown')
  WRITE(stdout,*) ' wannier plot '

  ALLOCATE ( u_matrix( n_wannier, n_wannier, nkstot) )
  ALLOCATE ( orbital( npwx, n_wannier) )

  !
  DO i = 1, n_wannier
     DO j = 1, n_wannier
        DO ik = 1, nkstot
           READ (20, * ) u_matrix(i,j,ik)
           !do nn = 1, nnb(ik)
           DO nn = 1, nnb
              READ (20, * ) ! m_matrix (i,j,nkp,nn)
           ENDDO
        ENDDO  !nkp
     ENDDO !j
  ENDDO !i
  !
  DO ik=1,iknum
     ikevc = ik + ikstart - 1
     CALL davcio (evc, 2*nwordwfc, iunwfc, ikevc, -1)
     npw = ngk(ik)
     WRITE(stdout,*) 'npw ',npw
     DO iw=1,n_wannier
        DO j=1,npw
           orbital(j,iw) = (0.0d0,0.0d0)
           DO ibnd=1,n_wannier
              orbital(j,iw) = orbital(j,iw) + u_matrix(iw,ibnd,ik)*evc(j,ibnd)
              WRITE(stdout,*) j, iw, ibnd, ik, orbital(j,iw), &
                              u_matrix(iw,ibnd,ik), evc(j,ibnd)
           ENDDO !ibnd
        ENDDO  !j
     ENDDO !wannier
     CALL davcio (orbital, 2*nwordwann, iunatsicwfc, ikevc, +1)
  ENDDO ! k-points

  DEALLOCATE ( u_matrix)
  WRITE(stdout,*) ' dealloc u '
  DEALLOCATE (  orbital)
  WRITE(stdout,*) ' dealloc orbital '
  !
END SUBROUTINE wan2sic

SUBROUTINE ylm_expansion
   USE io_global,  ONLY : stdout
   USE kinds, ONLY :  DP
   USE random_numbers,  ONLY : randy
   USE matrix_inversion
   USE wannier
   IMPLICIT NONE
   ! local variables
   INTEGER, PARAMETER :: lmax2=16
   INTEGER ::  lm, i, ir, iw, m
   real(DP), ALLOCATABLE :: r(:,:), rr(:), rp(:,:), ylm_w(:), ylm(:,:), mly(:,:)
   real(DP) :: u(3,3)

   ALLOCATE (r(3,lmax2), rp(3,lmax2), rr(lmax2), ylm_w(lmax2))
   ALLOCATE (ylm(lmax2,lmax2), mly(lmax2,lmax2) )

   ! generate a set of nr=lmax2 random vectors
   DO ir=1,lmax2
      DO i=1,3
         r(i,ir) = randy() -0.5d0
      ENDDO
   ENDDO
   rr(:) = r(1,:)*r(1,:) + r(2,:)*r(2,:) + r(3,:)*r(3,:)
   !- compute ylm(ir,lm)
   CALL ylmr2(lmax2, lmax2, r, rr, ylm)
   !- store the inverse of ylm(ir,lm) in mly(lm,ir)
   CALL invmat(lmax2, ylm, mly)
   !- check that r points are independent
   CALL check_inverse(lmax2, ylm, mly)

   DO iw=1, n_proj

      !- define the u matrix that rotate the reference frame
      CALL set_u_matrix (xaxis(:,iw),zaxis(:,iw),u)
      !- find rotated r-vectors
      rp(:,:) = matmul ( u(:,:) , r(:,:) )
      !- set ylm funtion according to wannier90 (l,mr) indexing in the rotaterd points
      CALL ylm_wannier(ylm_w,l_w(iw),mr_w(iw),rp,lmax2)

      csph(:,iw) = matmul (mly(:,:), ylm_w(:))

!      write (stdout,*)
!      write (stdout,'(2i4,2(2x,3f6.3))') l_w(iw), mr_w(iw), xaxis(:,iw), zaxis(:,iw)
!      write (stdout,'(16i6)')   (lm, lm=1,lmax2)
!      write (stdout,'(16f6.3)') (csph(lm,iw), lm=1,lmax2)

   ENDDO
   DEALLOCATE (r, rp, rr, ylm_w, ylm, mly )

   RETURN
END SUBROUTINE ylm_expansion

SUBROUTINE check_inverse(lmax2, ylm, mly)
   USE kinds, ONLY :  DP
   USE constants, ONLY :  eps8
   IMPLICIT NONE
   ! I/O variables
   INTEGER :: lmax2
   real(DP) :: ylm(lmax2,lmax2), mly(lmax2,lmax2)
   ! local variables
   real(DP), ALLOCATABLE :: uno(:,:)
   real(DP) :: capel
   INTEGER :: lm
   !
   ALLOCATE (uno(lmax2,lmax2) )
   uno = matmul(mly, ylm)
   capel = 0.d0
   DO lm = 1, lmax2
      uno(lm,lm) = uno(lm,lm) - 1.d0
   ENDDO
   capel = capel + sum ( abs(uno(1:lmax2,1:lmax2) ) )
!   write (stdout,*) "capel = ", capel
   IF (capel > eps8) CALL errore('ylm_expansion', &
                    ' inversion failed: r(*,1:nr) are not all independent !!',1)
   DEALLOCATE (uno)
   RETURN
END SUBROUTINE check_inverse

SUBROUTINE set_u_matrix(x,z,u)
   USE kinds, ONLY :  DP
   USE constants, ONLY : eps6
   IMPLICIT NONE
   ! I/O variables
   real(DP) :: x(3),z(3),u(3,3)
   ! local variables
   real(DP) :: xx, zz, y(3), coseno

   xx = sqrt(x(1)*x(1) + x(2)*x(2) + x(3)*x(3))
   IF (xx < eps6) CALL errore ('set_u_matrix',' |xaxis| < eps ',1)
!   x(:) = x(:)/xx
   zz = sqrt(z(1)*z(1) + z(2)*z(2) + z(3)*z(3))
   IF (zz < eps6) CALL errore ('set_u_matrix',' |zaxis| < eps ',1)
!   z(:) = z(:)/zz

   coseno = (x(1)*z(1) + x(2)*z(2) + x(3)*z(3))/xx/zz
   IF (abs(coseno) > eps6) CALL errore('set_u_matrix',' xaxis and zaxis are not orthogonal !',1)

   y(1) = (z(2)*x(3) - x(2)*z(3))/xx/zz
   y(2) = (z(3)*x(1) - x(3)*z(1))/xx/zz
   y(3) = (z(1)*x(2) - x(1)*z(2))/xx/zz

   u(1,:) = x(:)/xx
   u(2,:) = y(:)
   u(3,:) = z(:)/zz

!   write (stdout,'(3f10.7)') u(:,:)

   RETURN

END SUBROUTINE set_u_matrix

SUBROUTINE ylm_wannier(ylm,l,mr,r,nr)
!
! this routine returns in ylm(r) the values at the nr points r(1:3,1:nr)
! of the spherical harmonic identified  by indices (l,mr)
! in table 3.1 of the wannierf90 specification.
!
! No reference to the particular ylm ordering internal to Quantum ESPRESSO
! is assumed.
!
! If ordering in wannier90 code is changed or extended this should be the
! only place to be modified accordingly
!
   USE kinds, ONLY :  DP
   USE constants, ONLY : pi, fpi, eps8
   IMPLICIT NONE
! I/O variables
!
   INTEGER :: l, mr, nr
   real(DP) :: ylm(nr), r(3,nr)
!
! local variables
!
   real(DP), EXTERNAL :: s, p_z,px,py, dz2, dxz, dyz, dx2my2, dxy
   real(DP), EXTERNAL :: fz3, fxz2, fyz2, fzx2my2, fxyz, fxx2m3y2, fy3x2my2
   real(DP) :: rr, cost, phi
   INTEGER :: ir
   real(DP) :: bs2, bs3, bs6, bs12
   bs2 = 1.d0/sqrt(2.d0)
   bs3=1.d0/sqrt(3.d0)
   bs6 = 1.d0/sqrt(6.d0)
   bs12 = 1.d0/sqrt(12.d0)
!
   IF (l > 3 .or. l < -5 ) CALL errore('ylm_wannier',' l out of range ', 1)
   IF (l>=0) THEN
      IF (mr < 1 .or. mr > 2*l+1) CALL errore('ylm_wannier','mr out of range' ,1)
   ELSE
      IF (mr < 1 .or. mr > abs(l)+1 ) CALL errore('ylm_wannier','mr out of range',1)
   ENDIF

   DO ir=1, nr
      rr = sqrt( r(1,ir)*r(1,ir) +  r(2,ir)*r(2,ir) + r(3,ir)*r(3,ir) )
      IF (rr < eps8) CALL errore('ylm_wannier',' rr too small ',1)

      cost =  r(3,ir) / rr
      !
      !  beware the arc tan, it is defined modulo pi
      !
      IF (r(1,ir) > eps8) THEN
         phi = atan( r(2,ir)/r(1,ir) )
      ELSEIF (r(1,ir) < -eps8 ) THEN
         phi = atan( r(2,ir)/r(1,ir) ) + pi
      ELSE
         phi = sign( pi/2.d0,r(2,ir) )
      ENDIF


      IF (l==0) THEN   ! s orbital
                    ylm(ir) = s(cost,phi)
      ENDIF
      IF (l==1) THEN   ! p orbitals
         IF (mr==1) ylm(ir) = p_z(cost,phi)
         IF (mr==2) ylm(ir) = px(cost,phi)
         IF (mr==3) ylm(ir) = py(cost,phi)
      ENDIF
      IF (l==2) THEN   ! d orbitals
         IF (mr==1) ylm(ir) = dz2(cost,phi)
         IF (mr==2) ylm(ir) = dxz(cost,phi)
         IF (mr==3) ylm(ir) = dyz(cost,phi)
         IF (mr==4) ylm(ir) = dx2my2(cost,phi)
         IF (mr==5) ylm(ir) = dxy(cost,phi)
      ENDIF
      IF (l==3) THEN   ! f orbitals
         IF (mr==1) ylm(ir) = fz3(cost,phi)
         IF (mr==2) ylm(ir) = fxz2(cost,phi)
         IF (mr==3) ylm(ir) = fyz2(cost,phi)
         IF (mr==4) ylm(ir) = fzx2my2(cost,phi)
         IF (mr==5) ylm(ir) = fxyz(cost,phi)
         IF (mr==6) ylm(ir) = fxx2m3y2(cost,phi)
         IF (mr==7) ylm(ir) = fy3x2my2(cost,phi)
      ENDIF
      IF (l==-1) THEN  !  sp hybrids
         IF (mr==1) ylm(ir) = bs2 * ( s(cost,phi) + px(cost,phi) )
         IF (mr==2) ylm(ir) = bs2 * ( s(cost,phi) - px(cost,phi) )
      ENDIF
      IF (l==-2) THEN  !  sp2 hybrids
         IF (mr==1) ylm(ir) = bs3*s(cost,phi)-bs6*px(cost,phi)+bs2*py(cost,phi)
         IF (mr==2) ylm(ir) = bs3*s(cost,phi)-bs6*px(cost,phi)-bs2*py(cost,phi)
         IF (mr==3) ylm(ir) = bs3*s(cost,phi) +2.d0*bs6*px(cost,phi)
      ENDIF
      IF (l==-3) THEN  !  sp3 hybrids
         IF (mr==1) ylm(ir) = 0.5d0*(s(cost,phi)+px(cost,phi)+py(cost,phi)+p_z(cost,phi))
         IF (mr==2) ylm(ir) = 0.5d0*(s(cost,phi)+px(cost,phi)-py(cost,phi)-p_z(cost,phi))
         IF (mr==3) ylm(ir) = 0.5d0*(s(cost,phi)-px(cost,phi)+py(cost,phi)-p_z(cost,phi))
         IF (mr==4) ylm(ir) = 0.5d0*(s(cost,phi)-px(cost,phi)-py(cost,phi)+p_z(cost,phi))
      ENDIF
      IF (l==-4) THEN  !  sp3d hybrids
         IF (mr==1) ylm(ir) = bs3*s(cost,phi)-bs6*px(cost,phi)+bs2*py(cost,phi)
         IF (mr==2) ylm(ir) = bs3*s(cost,phi)-bs6*px(cost,phi)-bs2*py(cost,phi)
         IF (mr==3) ylm(ir) = bs3*s(cost,phi) +2.d0*bs6*px(cost,phi)
         IF (mr==4) ylm(ir) = bs2*p_z(cost,phi)+bs2*dz2(cost,phi)
         IF (mr==5) ylm(ir) =-bs2*p_z(cost,phi)+bs2*dz2(cost,phi)
      ENDIF
      IF (l==-5) THEN  ! sp3d2 hybrids
         IF (mr==1) ylm(ir) = bs6*s(cost,phi)-bs2*px(cost,phi)-bs12*dz2(cost,phi)+.5d0*dx2my2(cost,phi)
         IF (mr==2) ylm(ir) = bs6*s(cost,phi)+bs2*px(cost,phi)-bs12*dz2(cost,phi)+.5d0*dx2my2(cost,phi)
         IF (mr==3) ylm(ir) = bs6*s(cost,phi)-bs2*py(cost,phi)-bs12*dz2(cost,phi)-.5d0*dx2my2(cost,phi)
         IF (mr==4) ylm(ir) = bs6*s(cost,phi)+bs2*py(cost,phi)-bs12*dz2(cost,phi)-.5d0*dx2my2(cost,phi)
         IF (mr==5) ylm(ir) = bs6*s(cost,phi)-bs2*p_z(cost,phi)+bs3*dz2(cost,phi)
         IF (mr==6) ylm(ir) = bs6*s(cost,phi)+bs2*p_z(cost,phi)+bs3*dz2(cost,phi)
      ENDIF

   ENDDO

   RETURN

END SUBROUTINE ylm_wannier

!======== l = 0 =====================================================================
FUNCTION s(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) :: s, cost,phi
   s = 1.d0/ sqrt(fpi)
   RETURN
END FUNCTION s
!======== l = 1 =====================================================================
FUNCTION p_z(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) ::p_z, cost,phi
   p_z =  sqrt(3.d0/fpi) * cost
   RETURN
END FUNCTION p_z
FUNCTION px(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) ::px, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   px =  sqrt(3.d0/fpi) * sint * cos(phi)
   RETURN
END FUNCTION px
FUNCTION py(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) ::py, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   py =  sqrt(3.d0/fpi) * sint * sin(phi)
   RETURN
END FUNCTION py
!======== l = 2 =====================================================================
FUNCTION dz2(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) ::dz2, cost, phi
   dz2 =  sqrt(1.25d0/fpi) * (3.d0* cost*cost-1.d0)
   RETURN
END FUNCTION dz2
FUNCTION dxz(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) ::dxz, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   dxz =  sqrt(15.d0/fpi) * sint*cost * cos(phi)
   RETURN
END FUNCTION dxz
FUNCTION dyz(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) ::dyz, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   dyz =  sqrt(15.d0/fpi) * sint*cost * sin(phi)
   RETURN
END FUNCTION dyz
FUNCTION dx2my2(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) ::dx2my2, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   dx2my2 =  sqrt(3.75d0/fpi) * sint*sint * cos(2.d0*phi)
   RETURN
END FUNCTION dx2my2
FUNCTION dxy(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : fpi
   IMPLICIT NONE
   real(DP) ::dxy, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   dxy =  sqrt(3.75d0/fpi) * sint*sint * sin(2.d0*phi)
   RETURN
END FUNCTION dxy
!======== l = 3 =====================================================================
FUNCTION fz3(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : pi
   IMPLICIT NONE
   real(DP) ::fz3, cost, phi
   fz3 =  0.25d0*sqrt(7.d0/pi) * ( 5.d0 * cost * cost - 3.d0 ) * cost
   RETURN
END FUNCTION fz3
FUNCTION fxz2(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : pi
   IMPLICIT NONE
   real(DP) ::fxz2, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   fxz2 =  0.25d0*sqrt(10.5d0/pi) * ( 5.d0 * cost * cost - 1.d0 ) * sint * cos(phi)
   RETURN
END FUNCTION fxz2
FUNCTION fyz2(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : pi
   IMPLICIT NONE
   real(DP) ::fyz2, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   fyz2 =  0.25d0*sqrt(10.5d0/pi) * ( 5.d0 * cost * cost - 1.d0 ) * sint * sin(phi)
   RETURN
END FUNCTION fyz2
FUNCTION fzx2my2(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : pi
   IMPLICIT NONE
   real(DP) ::fzx2my2, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   fzx2my2 =  0.25d0*sqrt(105d0/pi) * sint * sint * cost * cos(2.d0*phi)
   RETURN
END FUNCTION fzx2my2
FUNCTION fxyz(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : pi
   IMPLICIT NONE
   real(DP) ::fxyz, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   fxyz =  0.25d0*sqrt(105d0/pi) * sint * sint * cost * sin(2.d0*phi)
   RETURN
END FUNCTION fxyz
FUNCTION fxx2m3y2(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : pi
   IMPLICIT NONE
   real(DP) ::fxx2m3y2, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   fxx2m3y2 =  0.25d0*sqrt(17.5d0/pi) * sint * sint * sint * cos(3.d0*phi)
   RETURN
END FUNCTION fxx2m3y2
FUNCTION fy3x2my2(cost,phi)
   USE kinds, ONLY :  DP
   USE constants, ONLY : pi
   IMPLICIT NONE
   real(DP) ::fy3x2my2, cost, phi, sint
   sint = sqrt(abs(1.d0 - cost*cost))
   fy3x2my2 =  0.25d0*sqrt(17.5d0/pi) * sint * sint * sint * sin(3.d0*phi)
   RETURN
END FUNCTION fy3x2my2
!
!
!-----------------------------------------------------------------------
SUBROUTINE radialpart(ng, q, alfa, rvalue, lmax, radial)
  !-----------------------------------------------------------------------
  !
  ! This routine computes a table with the radial Fourier transform
  ! of the radial functions.
  !
  USE kinds,      ONLY : dp
  USE constants,  ONLY : fpi
  USE cell_base,  ONLY : omega
  !
  IMPLICIT NONE
  ! I/O
  INTEGER :: ng, rvalue, lmax
  real(DP) :: q(ng), alfa, radial(ng,0:lmax)
  ! local variables
  real(DP), PARAMETER :: xmin=-6.d0, dx=0.025d0, rmax=10.d0

  real(DP) :: rad_int, pref, x
  INTEGER :: l, lp1, ir, ig, mesh_r
  real(DP), ALLOCATABLE :: bes(:), func_r(:), r(:), rij(:), aux(:)

  mesh_r = nint ( ( log ( rmax ) - xmin ) / dx + 1 )
  ALLOCATE ( bes(mesh_r), func_r(mesh_r), r(mesh_r), rij(mesh_r) )
  ALLOCATE ( aux(mesh_r))
  !
  !    compute the radial mesh
  !
  DO ir = 1, mesh_r
     x = xmin  + dble (ir - 1) * dx
     r (ir) = exp (x) / alfa
     rij (ir) = dx  * r (ir)
  ENDDO
  !
  IF (rvalue==1) func_r(:) = 2.d0 * alfa**(3.d0/2.d0) * exp(-alfa*r(:))
  IF (rvalue==2) func_r(:) = 1.d0/sqrt(8.d0) * alfa**(3.d0/2.d0) * &
                     (2.0d0 - alfa*r(:)) * exp(-alfa*r(:)*0.5d0)
  IF (rvalue==3) func_r(:) = sqrt(4.d0/27.d0) * alfa**(3.0d0/2.0d0) * &
                     (1.d0 - 2.0d0/3.0d0*alfa*r(:) + 2.d0*(alfa*r(:))**2/27.d0) * &
                                           exp(-alfa*r(:)/3.0d0)
  pref = fpi/sqrt(omega)
  !
  DO l = 0, lmax
     DO ig=1,ng
       CALL sph_bes (mesh_r, r(1), q(ig), l, bes)
       aux(:) = bes(:) * func_r(:) * r(:) * r(:)
       ! second r factor added upo suggestion by YY Liang
       CALL simpson (mesh_r, aux, rij, rad_int)
       radial(ig,l) = rad_int * pref
     ENDDO
  ENDDO

  DEALLOCATE (bes, func_r, r, rij, aux )
  RETURN
END SUBROUTINE radialpart
