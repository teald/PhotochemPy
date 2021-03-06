      module photochem
        implicit none
        ! location of files
        character(len=500) :: rootdir = 'PhotochemPy/'
        logical :: verbose = .true.

        ! Module variables (shared between subroutines)
        integer :: nz ! number of vertical grid points
        integer :: nz1 !nz-1
        integer :: nq ! number of long lived species
        integer :: nq1
        integer :: np ! number of particles
        integer :: nsp ! total number of species
        integer :: nsp2 ! total number of species, including HV and M
        integer :: nr ! number of reactions
        integer, parameter :: nmax = 300 ! max number of reactions a species can be involved in
        integer :: ks ! number of photo species
        integer :: kj ! number of photo reactions
        integer, parameter :: kw = 1000 ! max number of wavelength bins
        integer :: nw
        integer, parameter :: naq = 10 !number of aqueous species
        integer, parameter :: nt = 50 !number of temperatures in sulfate/H2O vapor pressure file (DATA/aerosol.table)
        integer, parameter :: nf = 50 !NT=number of pressures per temperature in DATA/aerosol.table
        integer :: lda
        integer :: neq

        ! Defined in species.dat
        integer :: iSL ! number of sl species
        real*8 :: FCO2, FN2 ! mixing ratios of N2 and CO2
        integer :: CO2_inert, N2_inert
        character(len=8), allocatable, dimension(:) :: ISPEC
        integer, allocatable, dimension(:) :: LBOUND
        real*8, allocatable, dimension(:) :: VDEP0
        real*8, allocatable, dimension(:) :: VDEP
        real*8, allocatable, dimension(:) :: FIXEDMR
        real*8, allocatable, dimension(:) :: distflux
        real*8, allocatable, dimension(:) :: SGFLUX
        real*8, allocatable, dimension(:) :: distheight
        integer, allocatable, dimension(:) :: MBOUND
        real*8, allocatable, dimension(:) :: SMFLUX
        real*8, allocatable, dimension(:) :: VEFF0
        real*8, allocatable, dimension(:) :: VEFF
        ! integer, allocatable, dimension(:) :: atomsO
        ! integer, allocatable, dimension(:) :: atomsH
        ! integer, allocatable, dimension(:) :: atomsC
        ! integer, allocatable, dimension(:) :: atomsS
        ! integer, allocatable, dimension(:) :: atomsN
        ! integer, allocatable, dimension(:) :: atomsCL
        real*8, allocatable, dimension(:) :: redoxstate
        double precision :: redox_factor
        real*8, allocatable, dimension(:) :: mass
        integer LSO2, LH2CO, lh2so4, lso4aer, lh2s ! indexes of a few things
        integer LCO, LH2O, LH2, LCH4, LO2, LH
        integer Ls8aer, Lhcaer, Lhcaer2, ls2, ls3, ls4
        integer lno, lo, LCO2, ls

        ! Defined in reactions.rx
        Character(len=8), allocatable, dimension(:,:) :: chemj
        integer, allocatable, dimension(:,:) :: jchem
        Character(len=8), allocatable, dimension(:) :: reactype
        real*8, allocatable, dimension(:,:) :: rateparams ! a new one.
        integer, allocatable, dimension(:,:,:) :: iloss
        integer, allocatable, dimension(:,:) :: iprod
        integer, allocatable, dimension(:) :: photoreac
        integer, allocatable, dimension(:) :: photonums
        integer, allocatable, dimension(:) :: photospec
        integer, allocatable, dimension(:) :: NUML, NUMP

        ! needed in read_atmosphere.f90
        real*8, allocatable, dimension(:,:) :: usol_init ! initial atmospheric composition
        real*8, allocatable, dimension(:) :: den ! total number density vs altitude
        real*8, allocatable, dimension(:) :: T ! Temperature vs altitude
        real*8, allocatable, dimension(:) :: EDD ! Eddy diffusion coefficients
        real*8, allocatable, dimension(:,:) :: aersol ! aersol parameter
        real*8, allocatable, dimension(:,:) :: wfall ! aersol parameter
        real*8, allocatable, dimension(:,:) :: rpar ! aersol parameter
        real*8, allocatable, dimension(:,:) :: aersol_init ! aersol parameter
        real*8, allocatable, dimension(:,:) :: wfall_init ! aersol parameter
        real*8, allocatable, dimension(:,:) :: rpar_init ! aersol parameter

        ! needed in Densty.f90
        real*8, allocatable, dimension(:) :: Press ! pressure in dynes
        real*8, allocatable, dimension(:) :: P ! pressure in bars

        ! needed in read_planet.f90
        real*8 :: G, Fscale, Alb, ztrop,far,R0,P0
        character(len=8) :: planet

        ! needed in read_photochem.f90
        real*8 :: AGL, EPSJ, prono, hcdens, zy
        integer :: Lgrid, IO2, ino, frak, ihztype

        ! needed in subroutine photgrid (in photgrid.f90)
        real*8, allocatable, dimension(:) :: z ! altitude of middle of grid
        real*8, allocatable, dimension(:) :: dz ! Delta_z of each altitude grid
        integer JTROP

        ! needed in initphoto.f90.
        real*8, dimension(kw) :: Flux ! Solar flux photons/(cm2 s)
        real*8, dimension(kw) :: wavl, wav, wavu ! wavelength bins
        real*8, dimension(17,4) :: alphap ! this stuff is for re-computing O2 cross sections in photo.dat
        real*8, dimension(17,4) :: beta  ! this. Ultimately I'll get rid of it
        integer, dimension(17) :: nk !this
        real*8, dimension(kw) :: SO2HZ ! this
        character(len=11),allocatable, dimension(:) :: photolabel
        real*8, allocatable, dimension(:,:,:) :: sq ! cross sections * qy
        real*8, allocatable, dimension(:,:) :: SIGNO

        ! needed in initmie.f90
        real*8, dimension(51) :: Rstand
        real*8, dimension(kw,51) :: W0HC
        real*8, dimension(kw,51) :: GHC, QEXTHC

        ! needed in Aertab.f90
        real*8, allocatable, dimension(:,:) :: VH2O
        real*8, allocatable, dimension(:,:) :: VH2SO4
        real*8, dimension(nf) :: ftab

        ! needed in Aercon.f90
        real*8, allocatable, dimension(:) :: FSULF
        real*8, allocatable, dimension(:) :: H2SO4S
        real*8, allocatable, dimension(:) :: S8S

        ! needed in photo.f90
        real*8, allocatable, dimension(:,:,:) :: QEXTT, W0T, GFT

        ! needed in dochem.f90
        real*8, allocatable, dimension(:,:) :: SL

        ! needed in rates.f90
        real*8, allocatable, dimension(:,:) :: A ! reaction rate coefficients

        ! needed in rainout.f90
        real*8, allocatable, dimension(:,:) :: H
        real*8, allocatable, dimension(:,:) :: RAINGC
        real*8, allocatable, dimension(:) :: RAIN
        real*8, allocatable, dimension(:,:) :: XSAVE

        ! needed in ltning.f90
        real*8 :: ZAPNO,ZAPO2,PRONOP,ZAPCO,ZAPH2,ZAPO

        ! needed in Difco.f90
        real*8, allocatable, dimension(:) :: HSCALE
        real*8, allocatable, dimension(:) :: tauedd
        real*8, allocatable, dimension(:) :: DK
        real*8, allocatable, dimension(:) :: H_ATM, BHN2, BH2N2
        real*8, allocatable, dimension(:,:) :: SCALE_H

        ! needed in PhotSatrat.f90
        real*8, allocatable, dimension(:) :: h2osat

        ! needed in setup.f90
        real*8, allocatable, dimension(:,:) :: DD,DL,DU,ADL,ADU,ADD

        ! needed in integrate.f90
        real*8, allocatable, dimension(:,:) :: usol_out
        real*8, allocatable, dimension(:) :: flow
        real*8, allocatable, dimension(:,:) :: fluxo
        real*8, allocatable, dimension(:,:) :: yp
        real*8, allocatable, dimension(:,:) :: yl


        ! some planet parameters and constants

      contains
        ! Module subroutines go here.
        ! include "fortran_subroutine_name.f90"
        ! e.g. include "Photo.f90"
        ! etc...

        ! ALL THESE WORK!!!
        include "read_species.f90" ! reads species.dat
        include "read_reactions.f90" ! reads reactions.rx
        include "read_atmosphere.f90" ! reads atmosphere.txt
        include "read_planet.f90" ! reads planet.dat
        include "read_photochem.f90" ! reads input_photochem.dat
        include "photgrid.f90" ! step up grid for photolysis calculations
        include "Rates.f90" ! calculates reaction rates
        include "Initphoto.f90"
        include "Xsections.f90"
        include "Initmie.f90"
        include "Rainout.f90"
        include "Aqueous.f90"
        include "Ltning.f90" ! Needs work for time dependent model
        include "Aertab.f90"
        include "Densty.f90"
        include "Aercon.f90"
        include "PhotSatrat.f90"
        include "Difco.f90"
        include "Sedmnt.f90"
        include "Dochem.f90"
        include "Chempl.f90"
        include "Photo.f90" ! need to deal with precision problem
        include "Rayleigh.f90"
        include "Twostr.f90"
        include "setup.f90"
        include "integrate_spike.f90"
        include "right_hand_side.f90"
        include "jacobian.f90"

        include "redox_conservation.f90"

        subroutine allocate_memory(nnz, nnq, nnp, nnsp,&
           nnr, kks, kkj)
          use reading_vars
          implicit none
          integer ::  nnz, nnq, nnp, nnsp, nnr, kks, kkj
          integer :: i,j,k
!f2py     intent(in) ::  nnz, nnq, nnp, nnsp, nnr, kks, kkj

          ! The dimensions.
          nz = nnz
          nz1 = nz-1
          nq  = nnq
          nq1 = nq
          np = nnp
          nsp = nnsp
          nsp2 = nnsp+2
          ks = kks
          kj = kkj
          nr = nnr
          LDA=3*NQ+1
          NEQ=NQ*NZ

          ! if allocated, then deallocate
          if (allocated(ISPEC).eqv..True.) then

            deallocate(ISPEC)
            deallocate(LBOUND)
            deallocate(vdep0)
            deallocate(vdep)
            deallocate(fixedmr)
            deallocate(distflux)
            deallocate(sgflux)
            deallocate(distheight)
            deallocate(MBOUND)
            deallocate(SMFLUX)
            deallocate(VEFF0)
            deallocate(VEFF)
            deallocate(atomsO)
            deallocate(atomsH)
            deallocate(atomsC)
            deallocate(atomsS)
            deallocate(atomsN)
            deallocate(atomsCl)
            deallocate(redoxstate)
            deallocate(mass)
            deallocate(chemj)
            deallocate(jchem)
            deallocate(reactype)
            deallocate(rateparams)
            deallocate(iloss)
            deallocate(iprod)
            deallocate(photoreac)
            deallocate(photospec)
            deallocate(photonums)
            deallocate(usol_init)
            deallocate(den)
            deallocate(T)
            deallocate(EDD)
            deallocate(aersol)
            deallocate(wfall)
            deallocate(rpar)
            deallocate(aersol_init)
            deallocate(wfall_init)
            deallocate(rpar_init)
            deallocate(numl)
            deallocate(nump)
            deallocate(Press)
            deallocate(P)
            deallocate(z)
            deallocate(dz)
            deallocate(photolabel)
            deallocate(sq)
            deallocate(SIGNO)
            deallocate(VH2O)
            deallocate(VH2SO4)
            deallocate(FSULF)
            deallocate(H2SO4S)
            deallocate(S8S)
            deallocate(QEXTT)
            deallocate(W0T)
            deallocate(GFT)
            deallocate(SL)
            deallocate(A)
            deallocate(H)
            deallocate(RAINGC)
            deallocate(RAIN)
            deallocate(XSAVE)
            deallocate(tauedd)
            deallocate(hscale)
            deallocate(H_ATM)
            deallocate(DK)
            deallocate(SCALE_H)
            deallocate(BHN2)
            deallocate(BH2N2)
            deallocate(h2osat)
            deallocate(DD)
            deallocate(DL)
            deallocate(DU)
            deallocate(ADL)
            deallocate(ADU)
            deallocate(ADD)
            deallocate(usol_out)
            deallocate(flow)
            deallocate(fluxo)
            deallocate(yp)
            deallocate(yl)

          endif

          ! allocate memory

          ! Defined in species.dat
          allocate(ISPEC(nsp2)) ! issue with this one
          allocate(LBOUND(nq))
          allocate(vdep0(nq))
          allocate(vdep(nq))
          allocate(fixedmr(nq))
          allocate(distflux(nq))
          allocate(sgflux(nq))
          allocate(distheight(nq))
          allocate(MBOUND(nq))
          allocate(SMFLUX(nq))
          allocate(VEFF0(nq))
          allocate(VEFF(nq))
          allocate(atomsO(nsp2))
          allocate(atomsH(nsp2))
          allocate(atomsC(nsp2))
          allocate(atomsS(nsp2))
          allocate(atomsN(nsp2))
          allocate(atomsCl(nsp2))
          allocate(redoxstate(nsp2))
          allocate(mass(nsp2))
          lbound = 0
          vdep0 = 0.d0
          vdep = 0.d0
          fixedmr = 0.d0
          distflux = 0.d0
          sgflux = 0.d0
          distheight = 0.d0
          mbound = 0
          smflux = 0.d0
          veff0 = 0.d0
          veff = 0.d0
          atomso = 0
          atomsh = 0
          atomsc = 0
          atomss = 0
          atomsn = 0
          atomscl = 0
          redoxstate = 0.d0
          redox_factor = 0.d0
          mass = 0.d0

          ! definined in reactions.rx
          allocate(chemj(5,nr))
          allocate(jchem(5,nr))
          allocate(reactype(nr))
          allocate(rateparams(4,nr))
          allocate(iloss(2,nsp,nmax))
          allocate(iprod(nsp,nmax))
          allocate(photoreac(kj))
          allocate(photospec(ks))
          allocate(photonums(kj))
          jchem = 0
          rateparams = 0.d0
          iloss = 0
          iprod = 0
          photoreac = 0
          photospec = 0
          photonums = 0

          ! needed in atmosphere.txt
          allocate(usol_init(nq,nz))
          allocate(den(nz))
          allocate(T(nz))
          allocate(EDD(nz))
          allocate(aersol(nz,np))
          allocate(wfall(nz,np))
          allocate(rpar(nz,np))
          allocate(aersol_init(nz,np))
          allocate(wfall_init(nz,np))
          allocate(rpar_init(nz,np))
          allocate(numl(nsp))
          allocate(nump(nsp))
          usol_init = 0.d0
          den = 0.d0
          t = 0.d0
          edd = 0.d0
          aersol = 0.d0
          wfall = 0.d0
          rpar = 0.d0
          aersol_init = 0.d0
          wfall_init = 0.d0
          rpar_init = 0.d0
          numl = 0
          nump = 0


          ! needed in Densty.f90
          allocate(Press(nz))
          allocate(P(nz))
          press = 0.d0
          p = 0.d0

          ! needed in photogrid.f90
          allocate(z(nz))
          allocate(dz(nz))
          z = 0.d0
          dz = 0.d0

          ! needed in initphoto.f90.
          allocate(photolabel(kj))
          allocate(sq(kj,nz,kw))
          allocate(SIGNO(nz,2))
          sq = 0.d0
          signo = 0.d0

          ! needed in Aertab.f90
          allocate(VH2O(Nf,nz))
          allocate(VH2SO4(Nf,nz))
          VH2O = 0.0d0
          VH2SO4 = 0.0d0

          ! needed in Aercon.f90
          allocate(FSULF(nz))
          allocate(H2SO4S(nz))
          allocate(S8S(nz))
          fsulf = 0.0d0
          h2so4s = 0.0d0
          s8s = 0.0d0

          ! needed in Photo.f90
          allocate(QEXTT(kw,nz,np))
          allocate(W0T(kw,nz,np))
          allocate(GFT(kw,nz,np))
          qextt = 0.0d0
          w0t = 0.0d0
          gft = 0.0d0

          ! needed in dochem.f90
          allocate(SL(NSP,NZ))
          sl = 0.0d0


          ! needed in rates.f90
          allocate(A(NR,NZ))
          ! zero out
          A = 0.0d0

          ! needed in rainout.f90
          allocate(H(NQ,NZ))
          allocate(RAINGC(NQ,NZ))
          allocate(RAIN(NZ))
          allocate(XSAVE(naq,nz))
          h = 0.0d0
          raingc = 0.0d0
          rain = 0.0d0
          xsave = 0.0d0

          ! needed in Difco.f90
          allocate(tauedd(nz))
          allocate(hscale(nz))
          allocate(H_ATM(nz))
          allocate(DK(nz))
          allocate(SCALE_H(nq,nz))
          allocate(BHN2(nz))
          allocate(BH2N2(nz))
          tauedd = 0.0d0
          hscale = 0.0d0
          h_atm = 0.0d0
          dk = 0.0d0
          scale_h = 0.0d0
          bhn2 = 0.0d0
          bh2n2 = 0.0d0

          ! needed in PhotSatrat.f90
          allocate(h2osat(nz))
          h2osat = 0.0d0

          ! needed in setup.f90
          allocate(DD(NQ1,NZ))
          allocate(DL(NQ1,NZ))
          allocate(DU(NQ1,NZ))
          allocate(ADL(NQ,NZ))
          allocate(ADU(NQ,NZ))
          allocate(ADD(NQ,NZ))
          dd = 0.0d0
          dl = 0.0d0
          du = 0.0d0
          adl = 0.0d0
          adu = 0.0d0
          add = 0.0d0

          ! integrate.f90
          allocate(usol_out(nq,nz))
          allocate(flow(nq))
          allocate(fluxo(nq,nz))
          allocate(yp(nq,nz))
          allocate(yl(nq,nz))
          usol_out(i,j) = 0.0d0
          flow = 0.0d0
          fluxo = 0.0d0
          yp = 0.0d0
          yl = 0.0d0

        end subroutine allocate_memory

      end module
