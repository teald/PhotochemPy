

      SUBROUTINE PHOTO(usol)
      ! Input is usol(nq,nz) (molecules/cm2)
      ! Output is prates (1/s), photolysis rates.
      ! prates is a module variable, so no need to be returned

      ! Module variables
      ! integer :: nz ! number of heights
      ! integer :: kj ! number photolysis species
      ! integer :: nj ! number of photo reactions
      ! integer :: nw ! number of wavelength bins
      ! real*8 :: sq(nj,nz,nw) ! cross sections * qy
      ! prates

      ! local variables
      implicit none
      real*8 :: SIGR(NZ)
      real*8 :: volmix(10,nz),icomp(10,nz),ncomp(nz)
      real*8 :: columndepth(KJ,NZ)
      integer :: l,i,j


      ! C   NO PREDISSOCIATION WAVELENGTHS (ALLEN AND FREDERICK, 1982)
      ! c- this used only if INO=0
      DATA LLNO/3*0, 2*2, 3*0, 2*1, 25*0/

      PM = 1.67E-24               !used in S8 (???) - what is this?
      BK = 1.38E-16               !Boltzmann constant - in erg/K
      RGAS = 8.3143E7             !erg/mol/K

      ! NEED molecular wt of atmosphere

      RMG = RGAS/(WT*G)           !gm cm^2/s^2/mol/K  / g *s^2/cm ->  cm/mol/K

      PI = 3.14159
      ZYR = ZY*PI/180.            ! note ZY is passed in subroutine call - solar angle in radians
      U0 = COS(ZYR)
      AM = 1./U0
! c -mc now in PHOTABLOK      ALB = 0.25                  ! albedo of surface

      NPHOT = NPHOT + 1        ! counts calls to this subroutine
      HC = 6.625E-27 * 3.00E10     !planck constant*speed of light, used in EFLUX
! c-mc erg s * cm/s -> erg cm

!below are used in old school NO calculations
      D0(1) = 1.2E-6              ! used for NO
      D0(2) = 2.6E-6              ! used for NO
      ALNO = 5.1E7                ! used for old NO
      QKNO = 1.5E-9               ! used for old NO
      DIJ = 1.65E9                ! used for old NO

      ! zero out prates
      do j=1,kj
        do i=1,nz
          prates(j,i)=0.0
        enddo
      enddo

! C ***** CALCULATE COLUMN DEPTHS ABOVE EACH COLLOCATION POINT FOR
! C ***** EACH SPECIES THAT ABSORBS PHOTONS

! c Kevin's likes nothing above the top
      HA = 0.0 * RMG*T(NZ)       !cm/mol/K * K -> cm/mol
      HAD = 0.0 * HA*DEN(NZ)
      TTOT(NZ) = HAD

      do k=1,kj   !kj=number of photolysis reactions
        columndepth(k,NZ)=absorbers(k,NZ)*HAD
      enddo

      do k=1,kj
        DO  M=1,NZ1
          I = NZ - M      !run through heights from the top down.

          HA = RMG*0.5*(T(I) + T(I+1))  !scale height RT/MG

! c-mc        DZ = Z(I+1) - Z(I)  !ACK - this is good, but should already exist as a vector
! c-mc in our new scheme DZ(I)=Z(I)-Z(I-1) so DZ(I+1)=Z(I+1)-Z(I)
! C ACK - may have to return when I take this to a variable grid

          EFAC = (1. - EXP(-DZ(I+1)/HA))*DEN(I)*HA     !column depth of each layer
          TTOT(I) = TTOT(I+1) + EFAC     !total column depth above height level I
          columndepth(k,I)= columndepth(k,I+1) &
                     + EFAC*SQRT(absorbers(k,i)*absorbers(k,i+1))
        enddo
      enddo


! c - cross section 'J numbers' that are used in the loop below
! c - for now, I am assuming that these species exist.  If they don't
! c - the program will crash because the Jnumber will be returned as a '0'
! c which will cause the sq(jnumber,..) or prate(jnumber,..) call to crash
! c - consider some IF's here, but this would also entail changing the output files, etc.


      if (IO2.EQ.1) then
        JO2=minloc(photoreac,1,ISPEC(INT(photoreac)).eq.'O2     ')+1
      !note this is for the O2 + Hv -> O + O reaction,which is the second O2 reaction
      endif

      if (INO.LE.2) then  !used if INO=0 or INO=1 - on JPL grid only... !actually for now using in high res too...
        JNO=minloc(photoreac,1,ISPEC(INT(photoreac)).eq.'NO     ')
! c-mab  print*,'JNO',JNO !debugging for templates w/o NO photolysis
      endif

!return to this sulfur stuff in a bit....

!OK - i want to keep this as it is used to track wavelength dependence of photolysis
!in fact, will probably need to expand this down the road.

        JSO2=minloc(photoreac,1,ISPEC(INT(photoreac)).eq.'SO2    ')

! a numbering scheme that works even if S8 isn't a species.  the key is to just not use JS8L,JS8R,JS8
        JS8L=minloc(photoreac,1,ISPEC(INT(photoreac)).eq.'S8     ')
        JS8R=JS8L+1
        JS8=JS8L+2

! C interpolate the optical properties from the Mie code onto the particle radii computed by photochemical code

     !this was in the time-stepping loop of the original code, but that seems like a mistake
! C-AP Since all model is in cm we should convert RSTAND
! c-mc test test test
! cgna - uncommented why isn't it doing this still??
! c-mc: this was in the time-stepping loop, so in Alex's code it was doing it every timestep, so RSTAND --> O.  Bad bug this was
     !DO k=1,34
      !RSTAND(k) = RSTAND(k)/10000.
     !ENDDO


! C  Calculate Qext , W0, G, for the current hydrocarbon aerosol distribution
! C qext and W0 are hardcoded for sulfate and sulfur in Twostrm.f
      if (NP.GE.3) then
        L3 = 3 !EWS - removes compilation warning
        do L=L3,NP  !loop over hydrocarbon particles ONLY RIGHT now
          DO I=1,nw
            DO J=1,NZ
              DO k=1,33  !ACK - hardcoded num particles (probably OK - this is how the HC grid was computed)
                IF ((RPAR(J,L).GE.RSTAND(k)).and.(RPAR(J,L).LT.RSTAND(k+1))) &
                THEN

                  drs = RSTAND(k+1) - RSTAND(k)
                  dr  = RPAR(J,L) - RSTAND(k)

                  QEXTT(I,J,L) = QEXTHC(I,k) + ((QEXTHC(I,k+1) - &
                    QEXTHC(I,k))/drs)*dr

                  GFT(I,J,L) = GHC(I,k) + ((GHC(I,k+1) - &
                  GHC(I,k))/drs)*dr

                  W0T(I,J,L) = W0HC(I,k) + ((W0HC(I,k+1) - &
                   W0HC(I,k))/drs)*dr

                 ENDIF
               ENDDO
             ENDDO
           ENDDO
         enddo
       endif

! ***** ***** ***** START WAVELENGTH LOOP   ***** ***** *****
      do L=1,nw

        Lold=L-10


        KN = 1      !exponentional sum index - reset below if IO2=1
        ALP = 1.    !exponentional sum coefficient - reset below if IO2=1

        IF (IO2.EQ.1 .AND. wavl(L).LE.2041. .AND. wavl(L).GE.1754.) then
          KN = NK(Lold) ! NK(L) are the number of exponential sum coefficients needed for O2
        endif  ! the coefficients are read in as ALPHAP(L,K) (where 1<K<4) and BETA(L,K)

! c-mc zero out Rayleigh scattering vectors:
        do i=1,nz
          ncomp(i)=0  !number of "major" species at each height
          do j=1,10     !10 is the (arbitrary) number of major absorbers
            volmix(j,i)=0.0  !mixing ratio of major species
            icomp(j,i)=0     !hardcoded "index" number of major species
          enddo
        enddo

!   LOOP OVER K'S AT LOW O2 LEVELS (this is a long loop)
!     note that 19 is also target for loop over L
!     so this is repeated once for L<1754 and L>2041A and NK(L) times for 1754<L<2041

        DO K=1,KN

          if (k.eq.1) then !compute Rayleigh scattering cross section (as a function of height?)
            do i=1,nz

              SIGR(i) = SIGRAY(WAV(L)) * (1. + 1.5*pCO2)  !Old rayleigh cross section

       !set up new Rayleigh scattering vectors
              do j=1,NSP
                if (SL(j,i)/DEN(i).GE. 0.01) then  !if more than 1% of atmosphere, consider Rayleigh contribution

! c              if (Z(i)/1e5.eq.107.5) print *, ispec(j)

                  if (ISPEC(j).eq.'CO2') then
                    ncomp(i)=ncomp(i)+1
                    volmix(ncomp(i),i)=SL(j,i)/DEN(i)
                    icomp(ncomp(i),i)=2
                  else if (ISPEC(j).eq.'N2') then
                    ncomp(i)=ncomp(i)+1
                    volmix(ncomp(i),i)=SL(j,i)/DEN(i)
                    icomp(ncomp(i),i)=3
                  else if (ISPEC(j).eq.'O2') then
                    ncomp(i)=ncomp(i)+1
                    volmix(ncomp(i),i)=SL(j,i)/DEN(i)
                    icomp(ncomp(i),i)=4
! c-mab: Added H2O 12/2016 as the 5th item. H2 is now 6 and He 7. Try this?
! c-mab: See "Rayleigh" routine for data reference...
                  else if (ISPEC(j).eq.'H2O') then
                    ncomp(i)=ncomp(i)+1
                    volmix(ncomp(i),i)=SL(j,i)/DEN(i)
                    icomp(ncomp(i),i)=5
                  else if (ISPEC(j).eq.'H2') then
                    ncomp(i)=ncomp(i)+1
                    volmix(ncomp(i),i) = USOL(LH2,1) !should matter for gas giants only
! c-mab: Rayleigh scattering routines typically assume the major species abundance don't change much vertically.
! c-mab: Thus ignoring any H2 loss due to photolysis and other reactions that are prevalent at high alt. for HJs.
! c-mab: Using fixedmr value for H2 allows for fastest convergence without qualitatively changing profiles.
                    icomp(ncomp(i),i)=6
                  else if (ISPEC(j).eq.'HE') then
                    ncomp(i)=ncomp(i)+1
                    volmix(ncomp(i),i) = FHE !should matter for gas giants only
                    icomp(ncomp(i),i)=7
! c-mab/mc: No scattering contributions for O, N, H, C or Cl!
                  else if (ISPEC(j).eq.'O'.or.ISPEC(J).eq.'H'.or. &
                   ISPEC(J).eq.'N'.or.ISPEC(J).eq.'S'.or. &
                   ISPEC(J).eq.'C'.or.ISPEC(J).eq.'Cl') then
! c-mab: Do nothing! Atoms don't scatter!
                  else
                    if(FH2.LT.0.5) then
! c-mab assuming "rest" to be Earth air is not valid for giant planets!
! c-mab this H2 fraction-based loop is a temporary fix--don't want to hardcode ignoring H
                      ncomp(i)=ncomp(i)+1
                      volmix(ncomp(i),i)=SL(j,i)/DEN(i)
                      icomp(ncomp(i),i)=1
!using Earth 'air' for the rocky planets - better than nothing? hard to know...
                      if (wavl(L).eq.2273) then
                        if (tempcount.eq.0) then
                          print *, ISPEC(j),'at ', Z(i)/1e5, 'km is major '// &
                          'species without Rayleigh data - using AIR', SL(j,i)/DEN(i)
                          tempcount=1
                        endif
                      endif
                    endif
                  endif
                endif !end loop over major species
              enddo  !end loop over all species in new Rayleigh setup loop
            enddo
          endif
        enddo  !end loop over height in Rayleigh loop
        tempcount=0

        call RAYLEIGH(wavl(l)*1e-4,ncomp,icomp,volmix,SIGR)

        endif   !end case for Rayleigh loop

        if (IO2 .EQ. 1) then   !re-compute O2 cross section via exponential sums
          if (wavl(L) .LE. 2041. .AND. wavl(L).GE.1754.) then
            ALP = ALPHAP(Lold,K)  !ALPHAP(17,4) are coeficients where 1<K<4
            do I=1,NZ
              sq(JO2,I,L)= SO2HZ(Lold) + BETA(Lold,K)
            enddo
          endif !end O2 sum computation loop
        endif !end IO2=1 loop



!mc - there used to be a mechanism for a Beer's law calculation when the optical depth was high or if IO2=0.
!removing this in favor of a permanent Twostr.f. Check the subversion archives if this ever needs to come back

        IKN=1
        IF (K.NE.KN) IKN=0   !output flag

        CALL TWOSTR(SIGR,U0,sq,WAV(L),L,S,N,IKN)  !two stream radiative tranfer
! this returns the Source function S to this code

        FLX = FLUX(L)*AGL*ALP*FSCALE

      !AGL is diurnal averaging factor, ALP is 1 if out of the SR band or IO2.NE.1
      ! or is the exponential sum coeffiecent if in the SR band and IO2.EQ.1
      ! FLUX is already corrected based on solar age (timeGa set in INPUTFILES/PLANET.dat)
      !FSACLE adjusts for position in the solar system (set in INPUTFILES/PLANET.dat)
          !FSCALE=1 is Earth, FSCALE=0.43 is Mars

! c compute photlysis rates for each reaction at each height (summed over wavelength)

        do j=1,kj
          do i=1,nz
            prates(j,i) = prates(j,i) + FLX*sq(j,i,L)*S(i)
          enddo
        enddo

! c save wavelength dependence of SO2 photolysis and optical depth
        do I=1,NZ
          PSO2MC(L,I) = FLX*sq(JSO2,I,L)*S(I)
          SALL(L,I) = S(I)
        enddo

        if (INO.LE.1) then
! C   NO PREDISSOCIATION IN THE D00 (1910 A) AND D10 (1830 A) BANDS
          if (wavl(L).LE.2500.0 .AND. wavl(L).GE.1754.) then
! c -mab: JNO = 0 when there is no NO photolysis in template (e.g. hjs).
            IF(JNO.NE.0)NOL = LLNO(Lold)!DATA LLNO/3*0, 2*2, 3*0, 2*1, 25*0/
            IF (NOL .NE. 0) THEN         !else bail out of loop over K (GOTO 19)

              IF (INO .EQ. 1) THEN
! C             old (cieslik and nicolet) method with intensities updated to
! C              frederick and hudson (1979)
                do I=1,NZ
                  RN2 = DIJ/(ALNO + DIJ + QKNO*DEN(I))
                  prates(JNO,I)=prates(JNO,I)+ 0.5*D0(NOL)*S(I)*RN2*AGL*ALP
                enddo
              ELSE
! C               frederick and allen method (effective cross sections)
                do I=1,NZ
                  prates(JNO,I)=prates(JNO,I) + FLX*SIGNO(I,NOL)*S(I)
                enddo
              ENDIF

            ENDIF     !if NOL=0, then do nothing...

          endif !end NO wavlength loop

        else  !end if loop which restricts this behavior to INO=0 or INO=1
!so ww get here if INO=2
!for now just use the NO photo rate generated from the band model, even at high res (Jim's suggestion)
!the below is dumb - it should be removed from the wavelength loop to make it more clear...
!leaving in place for now as I try to get results by 5PM...
          if(LTIMES.EQ.0) then
            if(L.eq.1) then
              print *, 'using hardcoded NO photorates'
              print *, 'be sure out.NOprates is valid for this atmosphere'
              open(60, file='out.NOprates',status='OLD')         ! formatted input
              read (60,*) (pratesNO(I),I=1,nz)
              close(60)
            endif
          endif
          if(L.eq.1) then
            do i=1,nz
              prates(JNO,I)=pratesNO(I)
            enddo
          endif
        endif !end INO=2 loop

!print out on last timestep
        if (N .NE. 0 .AND. K.EQ.KN) then !N.NE.0 only on last timestep,  KN=1 or 1-4 for L<17
          TAUR = SIGR(1)*TTOT(1)  !ack simple way of indicating total rayleigh optical depth. should be sum
          DELWAV = WAVU(L) - WAVL(L)
          EFLUX = 1.E6*HC*FLX/(WAV(L)*DELWAV*AGL)  !convert to W/m^2
          GFLUX = EFLUX*S(1)  !ground flux = TOA flux*optical path
          write(14, 120) L,WAV(L),TAUR,EFLUX,GFLUX,S(1)
 120      FORMAT(1X,I3,1X,F6.1,1X,1P4E10.3)
        endif





! C ***** ***** ***** END WAVELENGTH LOOP ***** ***** *****
      enddo



      if (JS8L.GT.0) then  !if gaseous S8 is in the model, compute the photolysis rate by black magic
! C
! C ***** CALCULATE S8 PHOTORATE USING ANDY YOUNG'S METHOD *****
! C     (ANC IS THE NUMBER OF COLLISIONS REQUIRED TO CLOSE THE RING,
! C      QCOL IS THE COLLISION CROSS SECTION OF A MOLECULE, SCOL IS
! C      THE COLLISION FREQUENCY, PS8R AND PS8L ARE THE PHOTOLYSIS
! C      RATES OF THE RING AND LINEAR S8 MOLECULES, RESPECTIVELY.)
! c   there is a bug in computing PS8 - the photolysis cross sections
! c   go through "crises" that seem to be unrelated to column depths
        ANC = 1.
        QCOL = 3.E-15
        DO I=1,NZ
          VMEAN = SQRT(8.*BK*T(I)/(WT*PM*PI))
          SCOL = DEN(I)*QCOL*VMEAN
          prates(JS8,I) = prates(JS8R,I) * prates(JS8L,I)/ &
                    (prates(JS8L,I) + SCOL/ANC)

          prates(JS8L,I)=0.0   !this keeps these predissociation reactions from
          prates(JS8R,I)=0.0   !factoring into the photoylsis/radiative transfer schemes

        enddo

      endif !end gaseous S8 loop


      ! if (N.NE.0) then  !on last timestep only...

!ACK - hardcoded wavelength grid

 !        DO 301 J=1,NZ
 ! 301     write(27,399) (PSO2MC(L,J),L=11,30)   !ACK  11-30 is 1762-2116.5A
 ! 399  format(20(1PE9.2,2X))
 !
 !      DO 302 J=1,NZ
 ! 302     write(27,499) (PSO2MC(L,J),L=31,45)   !ACK 31-45 is 2139.5-2516A
 ! 499  format(15(1PE9.2,2X))


!now print out so2 photorates on the high resolution grid
!       if (LGRID.eq.1) then
! !L-13 is 1786.25 and L-934 is 2246.75
!        L1=minloc(wavl,1,wavl.ge.1786.25)  !ACK hardcoded to high resolution grid
!        L2=minloc(wavl,1,wavl.ge.2246.75)  !ACK hardcoded to high resolution grid
!        write(61,*),L1,L2
!         fmtstr='(    (1PE9.2,2x))'
!         write(fmtstr(2:5),'(I4)')NZ
!        do j=L1,L2
!         write(61,fmtstr) (PSO2MC(j,i),i=1,nz)
!        enddo

      ! endif





! c - td printout - here we are going to write out where tau=1
! c - at each wavelength, need to find maximum height at which tau=1

!       opticaldepth=1.0
!       slev=EXP(-1.0*AM*opticaldepth)   !optical path length where tau=1 given zenith angle
!
!       smax=MAXLOC(SALL,2, SALL .le. slev)
!
! c orig      STAU=Z(MAXLOC(SALL,2, SALL .le. slev))/1e5   !original code not in loop
!       do L=1,nw
!          if (smax(L) .eq. 0) smax(L)=1.      !for some reason MAXLOC started returning 0 for the lower bound
!          STAU=Z(INT(smax(L)))/1e5
!       enddo
!
!       write(48,322) (STAU(L), L=1,nw) !write out tau=1 heights for the time-dependent codes
!
!  322  format(118(F10.3))  !ACK a hardcoded wavelength grid


!print cross sections - should disable for production runs
!or better yet, just don't save them in evolve script...
       !
       ! do L=1,nw
       !  do I=1,nz
!         write(29,*) (sq(J,I,L),J=1,kj)   !not needed for now
       !  enddo
       ! enddo


! c print wavlength and height grids...
! c so analysis programs can pick up on nz and nw

      !  do i=1,nz
      !   write(30,*) Z(i)
      !  enddo
      !
      !
      !  do L=1,nw
      !    write(31,*) wavl(L),wavu(L),wav(L)
      !    write(41,*), flux(L),relflux(L)
      !  enddo
      !  write(41,*) AM    !write out mu
      !
      ! do L=1,nw
      !  write(41,*) (SALL(L,I),I=1,NZ)
      ! enddo
      ! endif
      !



! C ***** FILL UP RATE MATRIX *****

      ! do j=1,kj
      !   do i=1,nz
      !     A(INT(photonums(j)),i)=prates(j,i)
      !   enddo
      ! enddo





! c      print *,'stopping in PHOTO'
! c      stop

      ! LTIMES = LTIMES + 1

      end subroutine

      real*8 FUNCTION SIGRAY(W)
      ! implicit real*8(A-H,O-Z)
      implicit none
      real*8 w1, w, w2, w4
      W1 = 1.E-4 * W
      W2 = W1 * W1
      W4 = W2 * W2
      SIGRAY = 4.006E-28*(1. + .0113/W2 + .00013/W4)/W4
      RETURN
      END
