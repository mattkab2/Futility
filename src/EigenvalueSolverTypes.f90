!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!  This manuscript has been authored by UT-Battelle, LLC, under Contract       !
!  No. DE-AC0500OR22725 with the U.S. Department of Energy. The United States  !
!  Government retains and the publisher, by accepting the article for          !
!  publication, acknowledges that the United States Government retains a       !
!  non-exclusive, paid-up, irrevocable, world-wide license to publish or       !
!  reproduce the published form of this manuscript, or allow others to do so,  !
!  for the United States Government purposes.                                  !
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!> @brief Module provides a eigenvalue system type and methods to solve systems
!> of equations
!>
!> Currently supported TPLs include:
!>  - SLEPc (with interfaces to EPS)
!>
!> Additional TPL support is planned for:
!>  - Trilinos
!>
!> @par Module Dependencies
!>  - @ref IntrType "IntrType": @copybrief IntrType
!>  - @ref BLAS "BLAS": @copybrief BLAS
!>  - @ref Times "Times": @copybrief Times
!>  - @ref ExceptionHandler "ExceptionHandler": @copybrief ExceptionHandler
!>  - @ref Allocs "Allocs": @copybrief Allocs
!>  - @ref ParameterLists "ParameterLists": @copybrief ParameterLists
!>  - @ref ParallelEnv "ParallelEnv": @copybrief ParallelEnv
!>  - @ref VectorTypes "VectorTypes": @copybrief VectorTypes
!>  - @ref MatrixTypes "MatrixTypes": @copybrief MatrixTypes
!>  - @ref LinearSolverTypes "LinearSolverTypes": @copybrief LinearSolverTypes
!>
!> @par EXAMPLES
!> @code
!>
!> @endcode
!>
!> @author Ben Collins
!>   @date 02/14/2016
!>
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
MODULE EigenvalueSolverTypes

  USE IntrType
  USE BLAS
  USE Times
  USE ExceptionHandler
  USE Allocs
  USE ParameterLists
  USE ParallelEnv
  USE VectorTypes
  USE MatrixTypes
  USE PreconditionerTypes
  USE Strings
  IMPLICIT NONE

#ifdef MPACT_HAVE_PETSC
#include <finclude/petsc.h>
#include <petscversion.h>
!petscisdef.h defines the keyword IS, and it needs to be reset
#ifdef MPACT_HAVE_SLEPC
#include <finclude/slepcsys.h>
#include <finclude/slepceps.h>
#endif
#undef IS
#endif

  PRIVATE
!
! List of public members
  PUBLIC :: eEigenvalueSolverType
  PUBLIC :: EigenvalueSolverType_Base
  PUBLIC :: EigenvalueSolverType_SLEPc

  !> set enumeration scheme for TPLs
  INTEGER(SIK),PARAMETER,PUBLIC :: SLEPC=0,TRILINOS=1,NATIVE=4
  !> set enumeration scheme for solver methods
  INTEGER(SIK),PARAMETER,PUBLIC :: POWER=0,JD=1,GD=2,ARNOLDI=3

  !> @brief the base eigenvalue solver type
  TYPE,ABSTRACT :: EigenvalueSolverType_Base
    !> Initialization status
    LOGICAL(SBK) :: isInit=.FALSE.
    !> Integer flag for the solution methodology desired
    INTEGER(SIK) :: solverMethod=-1
    !> Integer flag for the solution methodology desired
    INTEGER(SIK) :: TPLType=-1
    !> Pointer to the distributed memory parallel environment
    TYPE(MPI_EnvType),POINTER :: MPIparallelEnv => NULL()
    !> Pointer to the shared memory parallel environment TODO: eventually
    TYPE(OMP_EnvType) :: OMPparallelEnv
    !> size of eigenvalue system
    INTEGER(SIK) :: n=-1
    !> Maximum number of iterations
    INTEGER(SIK) :: maxit=-1
    !> Stopping tolerance
    REAL(SRK) :: tol
    !> eigenvalue of the system
    REAL(SRK) :: k
    !> Pointer to the MatrixType A
    CLASS(MatrixType),POINTER :: A => NULL()
    !> Pointer to the MatrixType B
    CLASS(MatrixType),POINTER :: B => NULL()
    !> Pointer to solution vector, x
    CLASS(VectorType),ALLOCATABLE :: X
    !> Timer to measure solution time
    TYPE(TimerType) :: SolveTime
  !
  !List of Type Bound Procedures
    CONTAINS
      !> Deferred routine for initializing the eigenvalue solver system
      PROCEDURE(evsolver_init_sub_absintfc),DEFERRED,PASS :: init
      !> Deferred routine for clearing the eigenvalue solver
      PROCEDURE(evsolver_sub_absintfc),DEFERRED,PASS :: clear
      !> Deferred routine for solving the eigenvalue system
      PROCEDURE(evsolver_sub_absintfc),DEFERRED,PASS :: solve
      !> Routine for setting A and B for eigenvalue solver system
      PROCEDURE,PASS :: setMat => setMat_EigenvalueSolverType_Base
      !> @copybrief EigenvalueSolverTypes::getResidual_EigenvalueSolverType_Base
      !> @copydetails EigenvalueSolverTypes::getResidual_EigenvalueSolverType_Base
      PROCEDURE,PASS :: getResidual => getResidual_EigenvalueSolverType_Base
      !> @copybrief EigenvalueSolverTypes::setConv_EigenvalueSolverType_Base
      !> @copydetails EigenvalueSolverTypes::setConv_EigenvalueSolverType_Base
      PROCEDURE,PASS :: setConv => setConv_EigenvalueSolverType_Base
      !> @copybrief EigenvalueSolverTypes::setX0_EigenvalueSolverType_Base
      !> @copydetails EigenvalueSolverTypes::setX0_EigenvalueSolverType_Base
      PROCEDURE,PASS :: setX0 => setX0_EigenvalueSolverType_Base
  ENDTYPE EigenvalueSolverType_Base

  !> Explicitly defines the interface for the clear and solve routines
  ABSTRACT INTERFACE
    SUBROUTINE evsolver_init_sub_absintfc(solver,MPIEnv,Params)
      IMPORT :: EigenvalueSolverType_Base, ParamType, MPI_EnvType
      CLASS(EigenvalueSolverType_Base),INTENT(INOUT) :: solver
      TYPE(MPI_EnvType),INTENT(IN),TARGET :: MPIEnv
      TYPE(ParamType),INTENT(IN) :: Params
    ENDSUBROUTINE evsolver_init_sub_absintfc

    SUBROUTINE evsolver_sub_absintfc(solver)
      IMPORT :: EigenvalueSolverType_Base
      CLASS(EigenvalueSolverType_Base),INTENT(INOUT) :: solver
    ENDSUBROUTINE evsolver_sub_absintfc
  ENDINTERFACE

  !> @brief The extended type for the SLEPc Eigenvalue Solvers
  TYPE,EXTENDS(EigenvalueSolverType_Base) :: EigenvalueSolverType_SLEPc
    !>
    LOGICAL(SBK) :: clops=.FALSE.
#ifdef MPACT_HAVE_SLEPC
    !> SLEPc Eigenvalue Solver type
    EPS :: eps
#endif
    !> store vector for imaginary term required by SLEPc
    TYPE(PETScVectorType) :: xi
!
!List of Type Bound Procedures
    CONTAINS
      !> @copybrief EigenvalueSolverTypes::init_EigenvalueSolverType_SLEPc
      !> @copydetails EigenvalueSolverTypes::init_EigenvalueSolverType_SLEPc
      PROCEDURE,PASS :: init => init_EigenvalueSolverType_SLEPc
      !> @copybrief EigenvalueSolverTypes::clear_EigenvalueSolverType_SLEPc
      !> @copydetails EigenvalueSolverTypes::clear_EigenvalueSolverType_SLEPc
      PROCEDURE,PASS :: clear => clear_EigenvalueSolverType_SLEPc
      !> @copybrief EigenvalueSolverTypes::solve_EigenvalueSolverType_SLEPc
      !> @copydetails EigenvalueSolverTypes::solve_EigenvalueSolverType_SLEPc
      PROCEDURE,PASS :: solve => solve_EigenvalueSolverType_SLEPc
  ENDTYPE EigenvalueSolverType_SLEPc

  !> Logical flag to check whether the required and optional parameter lists
  !> have been created yet for the Eigenvalue Solver Type.
  LOGICAL(SBK),SAVE :: EigenvalueSolverType_Paramsflag=.FALSE.

  !> The parameter lists to use when validating a parameter list for
  !> initialization for a Eigenvalue Solver Type.
  TYPE(ParamType),PROTECTED,SAVE :: EigenvalueSolverType_reqParams,EigenvalueSolverType_optParams

  !> Exception Handler for use in MatrixTypes
  TYPE(ExceptionHandlerType),SAVE :: eEigenvalueSolverType

  !> Name of module
  CHARACTER(LEN=*),PARAMETER :: modName='EIGENVALUESOLVERTYPES'

#ifdef MPACT_HAVE_SLEPC
      PetscErrorCode ierr
#endif

!
!===============================================================================
  CONTAINS
!
!-------------------------------------------------------------------------------
!> @brief Initializes the Eigenvalue Solver Type with a parameter list
!> @param pList the parameter list
!>
!> @param solver The eigen solver to act on
!> @param solverMethod The integer flag for which type of solution scheme to use
!> @param MPIparallelEnv The MPI environment description
!> @param OMPparallelEnv The OMP environment description
!> @param TimerName The name of the timer to be used for querying (optional)
!>
!> This routine initializes the data spaces for the SLEPc eigenvalue solver.
!>
    SUBROUTINE init_EigenvalueSolverType_SLEPc(solver,MPIEnv,Params)
      CHARACTER(LEN=*),PARAMETER :: myName='init_EigenvalueSolverType_SLEPc'
      CLASS(EigenvalueSolverType_SLEPc),INTENT(INOUT) :: solver
      TYPE(MPI_EnvType),INTENT(IN),TARGET :: MPIEnv
      TYPE(ParamType),INTENT(IN) :: Params
      TYPE(ParamType) :: validParams, tmpPL
      INTEGER(SIK) :: n,nlocal,solvertype,maxit
      REAL(SRK) :: tol
      LOGICAL(SBK) :: clops
      TYPE(STRINGType) :: pctype

      !Check to set up required and optional param lists.
      !IF(.NOT.EigenType_Paramsflag) CALL EigenType_Declare_ValidParams()

      IF(.NOT. MPIEnv%isInit()) THEN
        CALL eEigenvalueSolverType%raiseError('Incorrect input to '// &
          modName//'::'//myName//' - MPI Environment is not initialized!')
      ELSE
        solver%MPIparallelEnv => MPIEnv
      ENDIF
      !Validate against the reqParams and OptParams
      validParams=Params
      !CALL validParams%validate(EigenType_reqParams)

      n=0
      nlocal=0
      solvertype=-1
      !Pull Data from Parameter List
      CALL validParams%get('EigenvalueSolverType->n',n)
      CALL validParams%get('EigenvalueSolverType->nlocal',nlocal)
      CALL validParams%get('EigenvalueSolverType->solver',solvertype)
      CALL validParams%get('EigenvalueSolverType->preconditioner',pctype)
      CALL validParams%get('EigenvalueSolverType->tolerance',tol)
      CALL validParams%get('EigenvalueSolverType->max_iterations',maxit)
      IF(validParams%has('EigenvalueSolverType->SLEPc->cmdline_options')) &
        CALL validParams%get('EigenvalueSolverType->SLEPc->cmdline_options',clops)

      IF(.NOT. solver%isInit) THEN
        IF(n < 1) THEN
          CALL eEigenvalueSolverType%raiseError('Incorrect input to '// &
            modName//'::'//myName//' - Number of values (n) must be '// &
              'greater than 0!')
        ELSE
          solver%n=n
        ENDIF

        IF((nlocal < 1) .AND. (nlocal > n)) THEN
          CALL eEigenvalueSolverType%raiseError('Incorrect input to '// &
            modName//'::'//myName//' - Number of values (nlocal) must be '// &
              'greater than 0 and less than or equal to (n)!')
        ENDIF

        IF(tol<=0.0_SRK) THEN
          CALL eEigenvalueSolverType%raiseError('Incorrect input to '// &
            modName//'::'//myName//' - Tolerance must be '// &
              'greater than 0!')
        ELSE
          solver%tol=tol
        ENDIF

        IF(maxit < 1) THEN
          CALL eEigenvalueSolverType%raiseError('Incorrect input to '// &
            modName//'::'//myName//' - Maximum Iterations must be '// &
              'greater than 0!')
        ELSE
          solver%maxit=maxit
        ENDIF
#ifdef MPACT_HAVE_SLEPC
        CALL EPSCreate(solver%MPIparallelEnv%comm,solver%eps,ierr)
        CALL EPSSetProblemType(solver%eps,EPS_GNHEP,ierr)
        IF(ierr/=0) &
          CALL eEigenvalueSolverType%raiseError(modName//'::'//myName// &
            ' - SLEPc failed to initialize.')
        SELECTCASE(solvertype)
          CASE(POWER)
            CALL EPSSetType(solver%eps,EPSPOWER,ierr)
          CASE(JD)
            CALL EPSSetType(solver%eps,EPSJD,ierr)
            CALL EPSSetWhichEigenpairs(solver%eps,EPS_LARGEST_REAL,ierr)
          CASE(GD)
            CALL EPSSetType(solver%eps,EPSGD,ierr)
            CALL EPSSetWhichEigenpairs(solver%eps,EPS_LARGEST_REAL,ierr)
          CASE(ARNOLDI)
            CALL EPSSetType(solver%eps,EPSARNOLDI,ierr)
            CALL EPSSetWhichEigenpairs(solver%eps,EPS_LARGEST_REAL,ierr)
          CASE DEFAULT
            CALL eEigenvalueSolverType%raiseError('Incorrect input to '// &
              modName//'::'//myName//' - Unknow solver type.')
        ENDSELECT
        IF(ierr/=0) &
            CALL eEigenvalueSolverType%raiseError(modName//'::'//myName// &
              ' - SLEPc failed to set solver type')
        CALL EPSSetTolerances(solver%eps,solver%tol,solver%maxit,ierr)
        IF(ierr/=0) &
            CALL eEigenvalueSolverType%raiseError(modName//'::'//myName// &
              ' - SLEPc failed to set solver type')

        !TODO: Need to set PC type
        !get KSP
        !ksptype()
        !ksp pc
        !set KSP
#else
        CALL eEigenvalueSolverType%raiseError(modName//'::'//myName// &
          ' - SLEPc is not present in build')
#endif
        solver%SolverMethod=solvertype

        ALLOCATE(PETScVectorType :: solver%X)
        CALL tmpPL%clear()
        CALL tmpPL%add('VectorType->n',n)
        CALL tmpPL%add('VectorType->MPI_Comm_ID',solver%MPIparallelEnv%comm)
        CALL tmpPL%add('VectorType->nlocal',nlocal)
        CALL solver%X%init(tmpPL)
        CALL solver%xi%init(tmpPL)

        solver%TPLType=SLEPC
        solver%isInit=.TRUE.
      ELSE
        CALL eEigenvalueSolverType%raiseError('Incorrect call to '// &
          modName//'::'//myName//' - EigenvalueSolverType already initialized')
      ENDIF
      CALL validParams%clear()

    ENDSUBROUTINE init_EigenvalueSolverType_SLEPc

    SUBROUTINE setMat_EigenvalueSolverType_Base(solver,A,B)
      CLASS(EigenvalueSolverType_Base),INTENT(INOUT) :: solver
      CLASS(MatrixType),INTENT(IN),TARGET :: A
      CLASS(MatrixType),INTENT(IN),TARGET :: B

      solver%A=>A
      solver%B=>B
    ENDSUBROUTINE setMat_EigenvalueSolverType_Base

    SUBROUTINE getResidual_EigenvalueSolverType_Base(solver,resid,its)
      CLASS(EigenvalueSolverType_Base),INTENT(INOUT) :: solver
      REAL(SRK),INTENT(OUT) :: resid
      INTEGER(SIK),INTENT(OUT) :: its

      SELECTTYPE(solver); TYPE IS(EigenvalueSolverType_SLEPc)
#ifdef MPACT_HAVE_SLEPC
        CALL EPSComputeRelativeError(solver%eps,0,resid,ierr)
        CALL EPSGetIterationNumber(solver%eps,its,ierr)
#endif
      ENDSELECT
    ENDSUBROUTINE getResidual_EigenvalueSolverType_Base

    !> @param convTol A value representing the convergence behavior
    !> @param maxIters The maximum number of iterations to perform
    SUBROUTINE setConv_EigenvalueSolverType_Base(solver,convTol,maxIters)
      CLASS(EigenvalueSolverType_Base),INTENT(INOUT) :: solver
      REAL(SRK),INTENT(IN) :: convTol
      INTEGER(SIK),INTENT(IN) :: maxIters

      solver%tol=convTol
      solver%maxit=maxIters
    ENDSUBROUTINE setConv_EigenvalueSolverType_Base


    SUBROUTINE setX0_EigenvalueSolverType_Base(solver,x0)
      CLASS(EigenvalueSolverType_Base),INTENT(INOUT) :: solver
      CLASS(VectorType),INTENT(INOUT) :: x0

      SELECTTYPE(solver)
        TYPE IS(EigenvalueSolverType_SLEPc)
          SELECTTYPE(x0); TYPE IS(PETScVectorType)
#ifdef MPACT_HAVE_SLEPC
            CALL EPSSetInitialSpace(solver%eps,1,x0%b,ierr)
#endif
          ENDSELECT
      ENDSELECT
      CALL BLAS_copy(THISVECTOR=x0,NEWVECTOR=solver%X)
    ENDSUBROUTINE setX0_EigenvalueSolverType_Base
!
!-------------------------------------------------------------------------------
!> @brief Clears the SLEPc Eigen Solver Type
!> @param solver The eigen solver to act on
!>
!> This routine clears the data spaces
!>
    SUBROUTINE clear_EigenvalueSolverType_SLEPc(solver)
      CLASS(EigenvalueSolverType_SLEPc),INTENT(INOUT) :: solver

      solver%solverMethod=-1
      solver%TPLType=-1
      NULLIFY(solver%MPIparallelEnv)
      IF(solver%OMPparallelEnv%isInit()) CALL solver%OMPparallelEnv%clear
      solver%n=-1
      solver%maxit=-1
      solver%tol=0.0_SRK
      solver%k=0.0_SRK
      NULLIFY(solver%A)
      NULLIFY(solver%B)
      IF(solver%X%isInit) CALL solver%X%clear()
      IF(solver%xi%isInit) CALL solver%xi%clear()
#ifdef MPACT_HAVE_SLEPC
      CALL EPSDestroy(solver%eps,ierr)
#endif
      solver%isInit=.FALSE.
    ENDSUBROUTINE clear_EigenvalueSolverType_SLEPc
!
!-------------------------------------------------------------------------------
!> @brief Clears the SLEPc Eigen Solver Type
!> @param solver The eigen solver to act on
!>
!> This routine clears the data spaces
!>
    SUBROUTINE solve_EigenvalueSolverType_SLEPc(solver)
      CLASS(EigenvalueSolverType_SLEPc),INTENT(INOUT) :: solver
#ifdef MPACT_HAVE_SLEPC
      PetscScalar    kr, ki
      REAL(SRK) :: tmp(2)

      SELECTTYPE(A=>solver%A); TYPE IS(PETScMatrixType)
        SELECTTYPE(B=>solver%B); TYPE IS(PETScMatrixType)
          IF (.NOT.(A%isAssembled)) CALL A%assemble()
          IF (.NOT.(B%isAssembled)) CALL B%assemble()
          CALL EPSSetOperators(solver%eps,A%A,B%A,ierr)
        ENDSELECT
      ENDSELECT

      CALL EPSSetTolerances(solver%eps,solver%tol,solver%maxit,ierr)
      CALL EPSSolve(solver%eps,ierr)

      CALL EPSGetEigenvalue(solver%eps,0,kr,ki,ierr)
      solver%k=REAL(kr,SRK)

      SELECTTYPE(x=>solver%x); TYPE IS(PETScVectorType)
        CALL EPSGetEigenvector(solver%eps,0,x%b,solver%xi%b,ierr)
      ENDSELECT

      !repurposing ki and xi since it isn't needed
      CALL solver%xi%set(0.0_SRK)
      CALL BLAS_matvec(THISMATRIX=solver%A,X=solver%x,Y=solver%xi)
      CALL VecSum(solver%xi%b,ki,ierr)
      CALL BLAS_scal(THISVECTOR=solver%X,A=1.0_SRK/REAL(ki,SRK))
#endif
    ENDSUBROUTINE solve_EigenvalueSolverType_SLEPc
!
ENDMODULE EigenvalueSolverTypes
