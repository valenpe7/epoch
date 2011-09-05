MODULE evaluator

  USE mpi
  USE stack
  USE evaluator_blocks

  IMPLICIT NONE

CONTAINS

  SUBROUTINE basic_evaluate(input_stack, ix, iy, err)

    TYPE(primitive_stack), INTENT(IN) :: input_stack
    INTEGER, INTENT(IN) :: ix, iy
    INTEGER, INTENT(INOUT) :: err
    INTEGER :: i, ierr
    TYPE(stack_element) :: block

    eval_stack%stack_point = 0

    DO i = 1, input_stack%stack_point
      block = input_stack%entries(i)
      IF (block%ptype .EQ. c_pt_variable) THEN
        CALL push_on_eval(block%numerical_data)
      ENDIF

      IF (block%ptype .EQ. c_pt_species) THEN
        CALL do_species(block%value, ix, iy, err)
      ELSE IF (block%ptype .EQ. c_pt_operator) THEN
        CALL do_operator(block%value, ix, iy, err)
      ELSE IF (block%ptype .EQ. c_pt_constant) THEN
        CALL do_constant(block%value, ix, iy, err)
      ELSE IF (block%ptype .EQ. c_pt_function) THEN
        CALL do_functions(block%value, ix, iy, err)
      ENDIF

      IF (err .NE. c_err_none) THEN
        PRINT *, 'BAD block', err, block%ptype, i, block%value
        CALL MPI_ABORT(comm, errcode, ierr)
        STOP
      ENDIF
    ENDDO

  END SUBROUTINE basic_evaluate



  SUBROUTINE evaluate_at_point_to_array(input_stack, ix, iy, n_elements, &
      array, err)

    TYPE(primitive_stack), INTENT(IN) :: input_stack
    INTEGER, INTENT(IN) :: ix, iy
    INTEGER, INTENT(IN) :: n_elements
    REAL(num), DIMENSION(:), INTENT(INOUT) :: array
    INTEGER, INTENT(INOUT) :: err
    INTEGER :: i

    CALL basic_evaluate(input_stack, ix, iy, err)

    IF (eval_stack%stack_point .NE. n_elements) err = IOR(err, c_err_bad_value)

    ! Pop off the final answers
    DO i = MIN(eval_stack%stack_point,n_elements),1,-1
      array(i) = pop_off_eval()
    ENDDO

  END SUBROUTINE evaluate_at_point_to_array



  SUBROUTINE evaluate_and_return_all(input_stack, ix, iy, n_elements, &
      array, err)

    TYPE(primitive_stack), INTENT(IN) :: input_stack
    INTEGER, INTENT(IN) :: ix, iy
    INTEGER, INTENT(OUT) :: n_elements
    REAL(num), DIMENSION(:), POINTER :: array
    INTEGER, INTENT(INOUT) :: err
    INTEGER :: i

    IF (ASSOCIATED(array)) DEALLOCATE(array)

    CALL basic_evaluate(input_stack, ix, iy, err)

    n_elements = eval_stack%stack_point
    ALLOCATE(array(1:n_elements))

    ! Pop off the final answers
    DO i = n_elements,1,-1
      array(i) = pop_off_eval()
    ENDDO

  END SUBROUTINE evaluate_and_return_all



  FUNCTION evaluate_at_point(input_stack, ix, iy, err)

    TYPE(primitive_stack), INTENT(IN) :: input_stack
    INTEGER, INTENT(IN) :: ix, iy
    INTEGER, INTENT(INOUT) :: err
    REAL(num), DIMENSION(1) :: array
    REAL(num) :: evaluate_at_point

    CALL evaluate_at_point_to_array(input_stack, ix, iy, 1, array, err)
    evaluate_at_point = array(1)

  END FUNCTION evaluate_at_point



  FUNCTION evaluate(input_stack, err)

    TYPE(primitive_stack), INTENT(IN) :: input_stack
    INTEGER, INTENT(INOUT) :: err
    REAL(num) :: evaluate

    evaluate = evaluate_at_point(input_stack, 0, 0, err)

  END FUNCTION evaluate

END MODULE evaluator
