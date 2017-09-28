! Licensed under the Apache License, Version 2.0 (the "License");
! you may not use this file except in compliance with the License.
! You may obtain a copy of the License at
!
!     https://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software
! distributed under the License is distributed on an "AS IS" BASIS,
! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and
! limitations under the License.

module test_curve

  use iso_c_binding, only: c_bool, c_double, c_int
  use curve, only: &
       evaluate_curve_barycentric, evaluate_multi, specialize_curve, &
       evaluate_hodograph, subdivide_nodes, newton_refine, LOCATE_MISS, &
       LOCATE_INVALID, locate_point, elevate_nodes, get_curvature, &
       reduce_pseudo_inverse, projection_error, can_reduce, full_reduce, &
       compute_length
  use types, only: dp
  use unit_test_helpers, only: &
       MACHINE_EPS, print_status, get_random_nodes, get_id_mat
  implicit none
  private &
       test_evaluate_curve_barycentric, test_evaluate_multi, &
       test_specialize_curve, test_evaluate_hodograph, test_subdivide_nodes, &
       subdivide_points_check, test_newton_refine, test_locate_point, &
       test_elevate_nodes, test_get_curvature, test_reduce_pseudo_inverse, &
       pseudo_inverse_helper, test_projection_error, test_can_reduce, &
       test_full_reduce, test_compute_length
  public curve_all_tests

contains

  subroutine curve_all_tests(success)
    logical(c_bool), intent(inout) :: success

    call test_evaluate_curve_barycentric(success)
    call test_evaluate_multi(success)
    call test_specialize_curve(success)
    call test_evaluate_hodograph(success)
    call test_subdivide_nodes(success)
    call test_newton_refine(success)
    call test_locate_point(success)
    call test_elevate_nodes(success)
    call test_get_curvature(success)
    call test_reduce_pseudo_inverse(success)
    call test_projection_error(success)
    call test_can_reduce(success)
    call test_full_reduce(success)
    call test_compute_length(success)

  end subroutine curve_all_tests

  subroutine test_evaluate_curve_barycentric(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes(4, 3)
    real(c_double) :: lambda1(3), lambda2(3)
    real(c_double) :: evaluated(3, 3), expected(3, 3)
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "evaluate_curve_barycentric"

    ! CASE 1: Slightly complex example.
    nodes(1, :) = [0.0_dp, 0.0_dp, 0.0_dp]
    nodes(2, :) = [0.5_dp, 3.0_dp, 1.0_dp]
    nodes(3, :) = [1.5_dp, 4.0_dp, 1.0_dp]
    nodes(4, :) = [2.0_dp, 8.0_dp, 1.0_dp]
    lambda1 = [0.25_dp, 0.5_dp, 0.75_dp]
    lambda2 = [0.25_dp, 0.125_dp, -0.75_dp]
    expected(1, :) = [0.125_dp, 0.453125_dp, 0.109375_dp]
    expected(2, :) = [0.0859375_dp, 0.390625_dp, 0.119140625_dp]
    expected(3, :) = [0.421875_dp, -2.109375_dp, -0.421875_dp]
    call evaluate_curve_barycentric( &
         3, 3, nodes, 3, lambda1, lambda2, evaluated)

    if (all(evaluated == expected)) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_evaluate_curve_barycentric

  subroutine test_evaluate_multi(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes1(2, 3), nodes2(3, 2)
    real(c_double) :: s_vals1(129), s_vals2(65)
    real(c_double) :: evaluated1(129, 3), expected1(129, 3)
    real(c_double) :: evaluated2(65, 2), expected2(65, 2)
    integer :: i
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "evaluate_multi"

    ! CASE 1: Linear curve.
    do i = 1, 129
       s_vals1(i) = (i - 1) / 128.0_dp
    end do
    nodes1(1, :) = [1.0_dp, 1.0_dp, -7.0_dp]
    nodes1(2, :) = [2.0_dp, -1.0_dp, -4.0_dp]
    ! B(s) = [s + 1, 1 - 2 s, 3 s - 7]
    expected1(:, 1) = 1.0_dp + s_vals1
    expected1(:, 2) = 1.0_dp - 2.0_dp * s_vals1
    expected1(:, 3) = -7.0_dp + 3.0_dp * s_vals1
    call evaluate_multi( &
         1, 3, nodes1, 129, s_vals1, evaluated1)

    if (all(evaluated1 == expected1)) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Quadratic curve.
    do i = 1, 65
       s_vals2(i) = (i - 1) / 64.0_dp
    end do
    nodes2(1, :) = [0.0_dp, 0.0_dp]
    nodes2(2, :) = [2.0_dp, -1.0_dp]
    nodes2(3, :) = [3.0_dp, 2.0_dp]
    ! B(s) = [s(4 - s), 2s(2s - 1)]
    expected2(:, 1) = s_vals2 * (4.0_dp - s_vals2)
    expected2(:, 2) = 2.0_dp * s_vals2 * (2.0_dp * s_vals2 - 1.0_dp)
    call evaluate_multi( &
         2, 2, nodes2, 65, s_vals2, evaluated2)

    if (all(evaluated2 == expected2)) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_evaluate_multi

  subroutine test_specialize_curve(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: true_start, true_end
    real(c_double) :: nodes1(2, 2)
    real(c_double) :: new_nodes1(2, 2), expected1(2, 2)
    real(c_double) :: nodes2(3, 2), left_nodes(3, 2), right_nodes(3, 2)
    real(c_double) :: new_nodes2(3, 2)
    real(c_double) :: nodes3(4, 2), new_nodes3(4, 2), expected3(4, 2)
    real(c_double) :: nodes4(5, 2), new_nodes4(5, 2), expected4(5, 2)
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "specialize_curve"

    ! CASE 1: Linear curve.
    nodes1(1, :) = [0.0_dp, 0.0_dp]
    nodes1(2, :) = [1.0_dp, 1.0_dp]
    expected1(1, :) = [0.25_dp, 0.25_dp]
    expected1(2, :) = [0.75_dp, 0.75_dp]
    call specialize_curve( &
         1, 2, nodes1, 0.25_dp, 0.75_dp, 0.125_dp, 0.25_dp, &
         new_nodes1, true_start, true_end)

    if (all(new_nodes1 == expected1) .AND. &
         true_start == 0.15625_dp .AND. true_end == 0.21875_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Quadratic curve, after subdivision.
    nodes2(1, :) = [0.0_dp, 1.0_dp]
    nodes2(2, :) = [1.0_dp, 6.0_dp]
    nodes2(3, :) = [3.0_dp, 5.0_dp]
    call subdivide_nodes( &
         3, 2, nodes2, left_nodes, right_nodes)
    call specialize_curve( &
         2, 2, nodes2, 0.0_dp, 0.5_dp, 0.0_dp, 1.0_dp, &
         new_nodes2, true_start, true_end)

    if (all(new_nodes2 == left_nodes) .AND. &
         true_start == 0.0_dp .AND. true_end == 0.5_dp) then
       ! Do a "second" check for the right-hand nodes.
       call specialize_curve( &
            2, 2, nodes2, 0.5_dp, 1.0_dp, 0.0_dp, 1.0_dp, &
            new_nodes2, true_start, true_end)
       if (all(new_nodes2 == right_nodes) .AND. &
            true_start == 0.5_dp .AND. true_end == 1.0_dp) then
          call print_status(name, case_id, .TRUE.)
       else
          call print_status(name, case_id, .FALSE.)
          success = .FALSE.
       end if
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Cubic curve.
    nodes3(1, :) = [0.0_dp, 0.0_dp]
    nodes3(2, :) = [1.0_dp, -1.0_dp]
    nodes3(3, :) = [1.0_dp, -2.0_dp]
    nodes3(4, :) = [3.0_dp, 2.0_dp]
    expected3(1, :) = [171.0_dp, -187.0_dp] / 512.0_dp
    expected3(2, :) = [375.0_dp, -423.0_dp] / 512.0_dp
    expected3(3, :) = [499.0_dp, -579.0_dp] / 512.0_dp
    expected3(4, :) = [735.0_dp, -335.0_dp] / 512.0_dp
    call specialize_curve( &
         3, 2, nodes3, 0.125_dp, 0.625_dp, 0.0_dp, 1.0_dp, &
         new_nodes3, true_start, true_end)

    if (all(new_nodes3 == expected3) .AND. &
         true_start == 0.125_dp .AND. true_end == 0.625_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 4: Quartic curve.
    nodes4(1, :) = [0.0_dp, 5.0_dp]
    nodes4(2, :) = [1.0_dp, 6.0_dp]
    nodes4(3, :) = [1.0_dp, 7.0_dp]
    nodes4(4, :) = [3.0_dp, 6.0_dp]
    nodes4(5, :) = [3.0_dp, 7.0_dp]
    expected4(1, :) = [1.5625_dp, 6.375_dp]
    expected4(2, :) = [1.78125_dp, 6.4375_dp]
    expected4(3, :) = [2.015625_dp, 6.46875_dp]
    expected4(4, :) = [2.2578125_dp, 6.484375_dp]
    expected4(5, :) = [2.47265625_dp, 6.5234375_dp]
    call specialize_curve( &
         4, 2, nodes4, 0.5_dp, 0.75_dp, 0.0_dp, 1.0_dp, &
         new_nodes4, true_start, true_end)

    if (all(new_nodes4 == expected4) .AND. &
         true_start == 0.5_dp .AND. true_end == 0.75_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_specialize_curve

  subroutine test_evaluate_hodograph(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    logical(c_bool) :: local_success
    real(c_double) :: s_vals(5), s_val
    real(c_double) :: hodograph(1, 2), expected(1, 2)
    real(c_double) :: nodes1(2, 2), nodes2(3, 2), nodes3(4, 2)
    integer :: i
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "evaluate_hodograph"

    ! CASE 1: Linear curve.
    nodes1(1, :) = [0.0_dp, 0.0_dp]
    nodes1(2, :) = [1.0_dp, 1.0_dp]
    expected(1, :) = nodes1(2, :) - nodes1(1, :)
    s_vals(:2) = [0.25_dp, 0.75_dp]
    local_success = .TRUE.
    do i = 1, 2
       call evaluate_hodograph( &
            s_vals(i), 1, 2, nodes1, hodograph)
       if (any(hodograph /= expected)) then
          local_success = .FALSE.
          exit
       end if
    end do

    if (local_success) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Quadratic curve.
    nodes2(1, :) = [0.0_dp, 0.0_dp]
    nodes2(2, :) = [0.5_dp, 1.0_dp]
    nodes2(3, :) = [1.25_dp, 0.25_dp]
    !  B(s) = [s(s + 4)/4, s(8 - 7s)/4]
    ! B'(s) = [(2 + s)/2, (4 - 7s)/2]
    s_vals = [0.0_dp, 0.25_dp, 0.5_dp, 0.625_dp, 0.875_dp]
    local_success = .TRUE.
    do i = 1, 5
       s_val = s_vals(i)
       call evaluate_hodograph( &
            s_val, 2, 2, nodes2, hodograph)
       expected(1, :) = [ &
            (2.0_dp + s_val) / 2.0_dp, &
            (4.0_dp - 7.0_dp * s_val) / 2.0_dp]
       if (any(hodograph /= expected)) then
          local_success = .FALSE.
          exit
       end if
    end do
    if (local_success) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Cubic curve.
    nodes3(1, :) = [0.0_dp, 0.0_dp]
    nodes3(2, :) = [0.25_dp, 1.0_dp]
    nodes3(3, :) = [0.75_dp, 0.5_dp]
    nodes3(4, :) = [1.25_dp, 1.0_dp]
    !  B(s) = [s(3 + 3s - s^2)/4, s(5s^2 - 9s + 6)/2]
    ! B'(s) = [3(1 + 2s - s^2)/4, 3(5s^2 - 6s + 2)/2]
    s_vals = [0.125_dp, 0.5_dp, 0.75_dp, 1.0_dp, 1.125_dp]
    local_success = .TRUE.
    do i = 1, 5
       s_val = s_vals(i)
       call evaluate_hodograph( &
            s_val, 3, 2, nodes3, hodograph)
       expected(1, 1) = ( &
            3.0_dp * (1.0_dp + 2.0_dp * s_val - s_val * s_val) / 4.0_dp)
       expected(1, 2) = ( &
            1.5_dp * (5.0_dp * s_val * s_val - 6.0_dp * s_val + 2.0_dp))
       if (any(hodograph /= expected)) then
          local_success = .FALSE.
          exit
       end if
    end do
    if (local_success) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_evaluate_hodograph

  subroutine test_subdivide_nodes(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    logical(c_bool) :: local_success
    real(c_double) :: nodes1(2, 2), l_expected1(2, 2), r_expected1(2, 2)
    real(c_double) :: left_nodes1(2, 2), right_nodes1(2, 2)
    real(c_double) :: nodes2(3, 2), l_expected2(3, 2), r_expected2(3, 2)
    real(c_double) :: left_nodes2(3, 2), right_nodes2(3, 2)
    real(c_double) :: nodes3(4, 2), l_expected3(4, 2), r_expected3(4, 2)
    real(c_double) :: left_nodes3(4, 2), right_nodes3(4, 2)
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "subdivide_nodes"

    ! CASE 1: Linear curve.
    nodes1(1, :) = [0.0_dp, 1.0_dp]
    nodes1(2, :) = [4.0_dp, 6.0_dp]
    l_expected1(1, :) = [0.0_dp, 1.0_dp]
    l_expected1(2, :) = [2.0_dp, 3.5_dp]
    r_expected1(1, :) = [2.0_dp, 3.5_dp]
    r_expected1(2, :) = [4.0_dp, 6.0_dp]
    call subdivide_nodes( &
         2, 2, nodes1, left_nodes1, right_nodes1)

    if (all(left_nodes1 == l_expected1) .AND. &
         all(right_nodes1 == r_expected1)) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Evaluate subdivided parts of a line.
    call subdivide_points_check( &
         2, 2, 909203, 10489, local_success)
    if (local_success) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Quadratic curve.
    nodes2(1, :) = [0.0_dp, 1.0_dp]
    nodes2(2, :) = [4.0_dp, 6.0_dp]
    nodes2(3, :) = [7.0_dp, 3.0_dp]
    l_expected2(1, :) = [0.0_dp, 1.0_dp]
    l_expected2(2, :) = [2.0_dp, 3.5_dp]
    l_expected2(3, :) = [3.75_dp, 4.0_dp]
    r_expected2(1, :) = [3.75_dp, 4.0_dp]
    r_expected2(2, :) = [5.5_dp, 4.5_dp]
    r_expected2(3, :) = [7.0_dp, 3.0_dp]
    call subdivide_nodes( &
         3, 2, nodes2, left_nodes2, right_nodes2)

    if (all(left_nodes2 == l_expected2) .AND. &
         all(right_nodes2 == r_expected2)) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 4: Evaluate subdivided parts of a quadratic curve.
    call subdivide_points_check( &
         3, 2, 10920388, 7756, local_success)
    if (local_success) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 5: Cubic curve.
    nodes3(1, :) = [0.0_dp, 1.0_dp]
    nodes3(2, :) = [4.0_dp, 6.0_dp]
    nodes3(3, :) = [7.0_dp, 3.0_dp]
    nodes3(4, :) = [6.0_dp, 5.0_dp]
    l_expected3(1, :) = [0.0_dp, 1.0_dp]
    l_expected3(2, :) = [2.0_dp, 3.5_dp]
    l_expected3(3, :) = [3.75_dp, 4.0_dp]
    l_expected3(4, :) = [4.875_dp, 4.125_dp]
    r_expected3(1, :) = [4.875_dp, 4.125_dp]
    r_expected3(2, :) = [6.0_dp, 4.25_dp]
    r_expected3(3, :) = [6.5_dp, 4.0_dp]
    r_expected3(4, :) = [6.0_dp, 5.0_dp]
    call subdivide_nodes( &
         4, 2, nodes3, left_nodes3, right_nodes3)

    if (all(left_nodes3 == l_expected3) .AND. &
         all(right_nodes3 == r_expected3)) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 6: Evaluate subdivided parts of a cubic curve.
    call subdivide_points_check( &
         4, 2, 33981020, 81902302, local_success)
    if (local_success) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 7: Quartic curve (not hardcoded).
    call subdivide_points_check( &
         5, 2, 1190, 881, local_success)
    if (local_success) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_subdivide_nodes

  subroutine subdivide_points_check( &
       num_nodes, dimension_, multiplier, modulus, success)
    integer, intent(in) :: num_nodes, dimension_, multiplier, modulus
    logical(c_bool), intent(out) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes(num_nodes, dimension_)
    real(c_double) :: left(num_nodes, dimension_)
    real(c_double) :: right(num_nodes, dimension_)
    real(c_double) :: unit_interval(33), left_s(33), right_s(33)
    real(c_double) :: evaluated1(33, dimension_)
    real(c_double) :: evaluated2(33, dimension_)
    integer :: i

    success = .TRUE.

    call get_random_nodes(nodes, multiplier, modulus, num_bits=8)
    call subdivide_nodes( &
         num_nodes, dimension_, nodes, left, right)

    do i = 1, 33
       unit_interval(i) = (i - 1) / 32.0_dp
       left_s(i) = (i - 1) / 64.0_dp
       right_s(i) = (i + 31) / 64.0_dp
    end do

    call evaluate_multi( &
         num_nodes - 1, dimension_, nodes, 33, left_s, evaluated1)
    call evaluate_multi( &
         num_nodes - 1, dimension_, left, 33, unit_interval, evaluated2)
    if (.NOT. all(evaluated1 == evaluated2)) then
       success = .FALSE.
       return
    end if

    call evaluate_multi( &
         num_nodes - 1, dimension_, nodes, 33, right_s, evaluated1)
    call evaluate_multi( &
         num_nodes - 1, dimension_, right, 33, unit_interval, evaluated2)
    if (.NOT. all(evaluated1 == evaluated2)) then
       success = .FALSE.
       return
    end if

  end subroutine subdivide_points_check

  subroutine test_newton_refine(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes(4, 3)
    real(c_double) :: point(1, 3)
    real(c_double) :: new_s
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "newton_refine"

    ! CASE 1: Cubic in 3D.
    nodes(1, :) = [0.0_dp, 0.0_dp, 0.0_dp]
    nodes(2, :) = [1.0_dp, -1.0_dp, 1.0_dp]
    nodes(3, :) = [3.0_dp, 2.0_dp, 2.0_dp]
    nodes(4, :) = [2.0_dp, 2.0_dp, 4.0_dp]
    ! curve(1/2) = p
    point(1, :) = [1.75_dp, 0.625_dp, 1.625_dp]
    call newton_refine( &
         4, 3, nodes, point, 0.25_dp, new_s)

    if (110.0_dp * new_s == 57.0_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_newton_refine

  subroutine test_locate_point(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes1(3, 3), point1(1, 3)
    real(c_double) :: nodes2(3, 2), point2(1, 2)
    real(c_double) :: nodes3(4, 2), point3(1, 2)
    real(c_double) :: s_val
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "locate_point"

    ! CASE 1: Quadratic in 3D (with match).
    nodes1(1, :) = 0
    nodes1(2, :) = [3.0_dp, 0.0_dp, -1.0_dp]
    nodes1(3, :) = [1.0_dp, 1.0_dp, 3.0_dp]
    point1(1, :) = [43.0_dp, 1.0_dp, -11.0_dp] / 64.0_dp
    call locate_point( &
         3, 3, nodes1, point1, s_val)

    if (s_val == 0.125_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Quadratic in 2D (without match).
    nodes2(1, :) = 0
    nodes2(2, :) = [0.5_dp, 1.0_dp]
    nodes2(3, :) = [1.0_dp, 0.0_dp]
    point2(1, :) = [0.5_dp, 2.0_dp]
    call locate_point( &
         3, 2, nodes2, point2, s_val)

    if (s_val == LOCATE_MISS) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Self-intersecting cubic in 3D (will cause failure).
    nodes3(1, :) = [0.0_dp, 2.0_dp]
    nodes3(2, :) = [-1.0_dp, 0.0_dp]
    nodes3(3, :) = [1.0_dp, 1.0_dp]
    nodes3(4, :) = [-0.75_dp, 1.625_dp]
    point3(1, :) = [-0.25_dp, 1.375_dp]
    call locate_point( &
         4, 2, nodes3, point3, s_val)

    if (s_val == LOCATE_INVALID) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_locate_point

  subroutine test_elevate_nodes(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes1(2, 2), elevated1(3, 2), expected1(3, 2)
    real(c_double) :: nodes2(3, 3), elevated2(4, 3), expected2(4, 3)
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "elevate_nodes"

    ! CASE 1: Linear curve.
    nodes1(1, :) = 0
    nodes1(2, :) = [2.0_dp, 4.0_dp]
    expected1(1, :) = [0.0_dp, 0.0_dp]
    expected1(2, :) = [1.0_dp, 2.0_dp]
    expected1(3, :) = [2.0_dp, 4.0_dp]
    call elevate_nodes( &
         2, 2, nodes1, elevated1)

    if (all(elevated1 == expected1)) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Quadratic curve.
    nodes2(1, :) = [0.0_dp, 0.5_dp, 0.75_dp]
    nodes2(2, :) = [3.0_dp, 0.5_dp, 3.0_dp]
    nodes2(3, :) = [6.0_dp, 0.5_dp, 2.25_dp]
    expected2(1, :) = [0.0_dp, 0.5_dp, 0.75_dp]
    expected2(2, :) = [2.0_dp, 0.5_dp, 2.25_dp]
    expected2(3, :) = [4.0_dp, 0.5_dp, 2.75_dp]
    expected2(4, :) = [6.0_dp, 0.5_dp, 2.25_dp]
    call elevate_nodes( &
         3, 3, nodes2, elevated2)

    if (all(elevated2 == expected2)) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_elevate_nodes

  subroutine test_get_curvature(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes1(2, 2), nodes2(3, 2)
    real(c_double) :: s_val, tangent_vec(1, 2), curvature
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "get_curvature"

    ! CASE 1: Linear curve.
    nodes1(1, :) = 0
    nodes1(2, :) = 1
    s_val = 0.5_dp
    call evaluate_hodograph( &
         s_val, 1, 2, nodes1, tangent_vec)
    call get_curvature( &
         2, 2, nodes1, tangent_vec, s_val, curvature)
    if (curvature == 0.0_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Linear curve, degree-elevated to quadratic.
    nodes2(1, :) = 0
    nodes2(2, :) = 0.5_dp
    nodes2(3, :) = 1
    s_val = 0.25_dp
    call evaluate_hodograph( &
         s_val, 2, 2, nodes2, tangent_vec)
    call get_curvature( &
         3, 2, nodes2, tangent_vec, s_val, curvature)
    if (curvature == 0.0_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Quadratic curve.
    nodes2(1, :) = 0
    nodes2(2, :) = [0.5_dp, 1.0_dp]
    nodes2(3, :) = [1.0_dp, 0.0_dp]
    s_val = 0.5_dp
    call evaluate_hodograph( &
         s_val, 2, 2, nodes2, tangent_vec)
    call get_curvature( &
         3, 2, nodes2, tangent_vec, s_val, curvature)
    if (curvature == -4.0_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_get_curvature

  subroutine test_reduce_pseudo_inverse(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    logical(c_bool) :: not_implemented
    real(c_double) :: nodes1(2, 2), reduced1(1, 2), expected1(1, 2)
    real(c_double) :: nodes2(3, 2), reduced2(2, 2), expected2(2, 2)
    real(c_double) :: nodes3(4, 3), reduced3(3, 3), expected3(3, 3)
    real(c_double) :: nodes4(5, 1), reduced4(4, 1), expected4(4, 1)
    real(c_double) :: reduced5(4, 4), expected5(4, 4)
    real(c_double) :: nodes6(6, 2), reduced6(5, 2)
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "reduce_pseudo_inverse"

    ! CASE 1: Reduce from line to point/constant.
    nodes1(1, :) = [-2.0_dp, 1.0_dp]
    nodes1(2, :) = nodes1(1, :)
    expected1(1, :) = nodes1(1, :)
    call reduce_pseudo_inverse( &
         2, 2, nodes1, reduced1, not_implemented)
    if (all(reduced1 == expected1) .AND. .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Reduce a degree-elevated line (as quadratic).
    nodes2(1, :) = 0
    nodes2(2, :) = [1.0_dp, 2.0_dp]
    nodes2(3, :) = [2.0_dp, 4.0_dp]
    expected2(1, :) = 0
    expected2(2, :) = [2.0_dp, 4.0_dp]
    call reduce_pseudo_inverse( &
         3, 2, nodes2, reduced2, not_implemented)
    if (all(reduced2 == expected2) .AND. .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Test that degree 2->1 reduction is actually a pseudo-inverse.
    call pseudo_inverse_helper(2, reduced2, expected2, not_implemented)
    if (all(reduced2 == expected2) .AND. .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 4: Reduce a quadratic that is not a deg.-elevated line.
    nodes2(1, :) = 0
    nodes2(2, :) = [1.0_dp, 1.5_dp]
    nodes2(3, :) = [2.0_dp, 0.0_dp]
    expected2(1, :) = [0.0_dp, 0.5_dp]
    expected2(2, :) = [2.0_dp, 0.5_dp]
    call reduce_pseudo_inverse( &
         3, 2, nodes2, reduced2, not_implemented)
    if (all(reduced2 == expected2) .AND. .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 5: Reduce a degree-elevated quadratic (as cubic).
    nodes3(1, :) = [0.0_dp, 0.5_dp, 0.75_dp]
    nodes3(2, :) = [2.0_dp, 0.5_dp, 2.25_dp]
    nodes3(3, :) = [4.0_dp, 0.5_dp, 2.75_dp]
    nodes3(4, :) = [6.0_dp, 0.5_dp, 2.25_dp]
    expected3(1, :) = nodes3(1, :)
    expected3(2, :) = [3.0_dp, 0.5_dp, 3.0_dp]
    expected3(3, :) = nodes3(4, :)
    call reduce_pseudo_inverse( &
         4, 3, nodes3, reduced3, not_implemented)
    if (all(reduced3 == expected3) .AND. .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 6: Test that degree 3->2 reduction is actually a pseudo-inverse.
    call pseudo_inverse_helper(3, reduced3, expected3, not_implemented)
    if (maxval(abs(reduced3 - expected3)) < MACHINE_EPS .AND. &
         .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 7: Reduce a degree-elevated cubic (as quartic).
    nodes4(:, 1) = [0.0_dp, 0.75_dp, 2.0_dp, 2.75_dp, 2.0_dp]
    expected4(:, 1) = [0.0_dp, 1.0_dp, 3.0_dp, 2.0_dp]
    call reduce_pseudo_inverse( &
         5, 1, nodes4, reduced4, not_implemented)
    if (all(reduced4 == expected4) .AND. .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 8: Test that degree 4->3 reduction is actually a pseudo-inverse.
    call pseudo_inverse_helper(4, reduced5, expected5, not_implemented)
    if (maxval(abs(reduced3 - expected3)) < MACHINE_EPS .AND. &
         .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 9: Unsupported degree
    call get_random_nodes(nodes6, 9177093, 16718, num_bits=8)
    call reduce_pseudo_inverse( &
         6, 2, nodes6, reduced6, not_implemented)
    if (not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_reduce_pseudo_inverse

  subroutine pseudo_inverse_helper(degree, result_, id_mat, not_implemented)
    integer, intent(in) :: degree
    real(c_double), intent(out) :: result_(degree, degree)
    real(c_double), intent(out) :: id_mat(degree, degree)
    logical(c_bool), intent(out) :: not_implemented
    ! Variables outside of signature.
    real(c_double) :: nodes(degree + 1, degree + 1)
    real(c_double) :: reduction_mat(degree, degree + 1)
    real(c_double) :: elevation_mat(degree + 1, degree)

    nodes = get_id_mat(degree + 1)
    call reduce_pseudo_inverse( &
         degree + 1, degree + 1, nodes, reduction_mat, not_implemented)
    if (not_implemented) then
       return
    end if

    id_mat = get_id_mat(degree)
    call elevate_nodes( &
         degree, degree, id_mat, elevation_mat)

    result_ = matmul(reduction_mat, elevation_mat)

  end subroutine pseudo_inverse_helper

  subroutine test_projection_error(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes1(2, 2), projected1(2, 2)
    real(c_double) :: nodes2(1, 2), projected2(1, 2)
    real(c_double) :: error
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "projection_error"

    ! CASE 1: Line projected onto self.
    nodes1(1, :) = [0.0_dp, 4.0_dp]
    nodes1(2, :) = [3.0_dp, 0.0_dp]
    projected1 = nodes1
    call projection_error( &
         2, 2, nodes1, projected1, error)
    if (error == 0.0_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Line projected with some error.
    projected1(1, :) = [0.5_dp, 4.5_dp]
    projected1(2, :) = [2.5_dp, 0.5_dp]
    call projection_error( &
         2, 2, nodes1, projected1, error)
    if (5.0_dp * error == 1.0_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Point/constant projected onto self.
    nodes2 = 0
    projected2 = 0
    call projection_error( &
         1, 2, nodes2, projected2, error)
    if (error == 0.0_dp) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_projection_error

  subroutine test_can_reduce(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes1(1, 2)
    real(c_double) :: nodes2(2, 3)
    real(c_double) :: nodes3(3, 2)
    real(c_double) :: nodes4(4, 2)
    real(c_double) :: nodes5(5, 2)
    real(c_double) :: nodes6(6, 2)
    integer(c_int) :: cr_success
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "can_reduce"

    ! CASE 1: Point/constant.
    nodes1(1, :) = [0.0_dp, 1.0_dp]
    call can_reduce( &
         1, 2, nodes1, cr_success)
    if (cr_success == 0) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Linear curve, reduce-able.
    nodes2(1, :) = [1.0_dp, 3.0_dp, 4.0_dp]
    nodes2(2, :) = nodes2(1, :)
    call can_reduce( &
         2, 3, nodes2, cr_success)
    if (cr_success == 1) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Linear curve, **not** reduce-able.
    nodes2(1, :) = [1.0_dp, 3.0_dp, 4.0_dp]
    nodes2(2, :) = [2.0_dp, 5.0_dp, 0.5_dp]
    call can_reduce( &
         2, 3, nodes2, cr_success)
    if (cr_success == 0) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 4: Quadratic curve, reduce-able.
    nodes3(1, :) = [0.0_dp, 3.5_dp]
    nodes3(3, :) = [2.0_dp, 2.0_dp]
    nodes3(2, :) = 0.5_dp * (nodes3(1, :) + nodes3(3, :))
    call can_reduce( &
         3, 2, nodes3, cr_success)
    if (cr_success == 1) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 5: Quadratic curve, **not** reduce-able.
    nodes3(1, :) = [0.0_dp, 3.5_dp]
    nodes3(2, :) = [2.0_dp, 3.0_dp]
    nodes3(3, :) = [2.0_dp, 2.0_dp]
    call can_reduce( &
         3, 2, nodes3, cr_success)
    if (cr_success == 0) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 6: Cubic curve, reduce-able.
    nodes4(1, :) = [3.0_dp, 5.0_dp]
    nodes4(2, :) = [1.0_dp, 6.0_dp]
    nodes4(3, :) = [0.0_dp, 7.5_dp]
    nodes4(4, :) = nodes4(1, :) - 3 * nodes4(2, :) + 3 * nodes4(3, :)
    call can_reduce( &
         4, 2, nodes4, cr_success)
    if (cr_success == 1) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 7: Cubic curve, **not** reduce-able.
    nodes4(1, :) = [5.0_dp, 0.0_dp]
    nodes4(2, :) = [1.0_dp, 9.0_dp]
    nodes4(3, :) = [5.0_dp, 17.5_dp]
    nodes4(4, :) = [0.0_dp, 7.0_dp]
    call can_reduce( &
         4, 2, nodes4, cr_success)
    if (cr_success == 0) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 8: Quartic curve, reduce-able.
    nodes5(1, :) = [0.0_dp, 0.0_dp]
    nodes5(2, :) = [1.0_dp, 2.0_dp]
    nodes5(3, :) = [2.0_dp, 3.5_dp]
    nodes5(4, :) = [5.0_dp, 3.5_dp]
    nodes5(5, :) = ( &
         4 * nodes5(4, :) - 6 * nodes5(3, :) + 4 * nodes5(2, :) - nodes5(1, :))
    call can_reduce( &
         5, 2, nodes5, cr_success)
    if (cr_success == 1) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 9: Quartic curve, **not** reduce-able.
    nodes5(1, :) = [0.0_dp, 0.0_dp]
    nodes5(2, :) = [1.0_dp, 2.0_dp]
    nodes5(3, :) = [2.0_dp, 3.5_dp]
    nodes5(4, :) = [5.0_dp, 3.5_dp]
    nodes5(5, :) = [8.0_dp, 18.0_dp]
    call can_reduce( &
         5, 2, nodes5, cr_success)
    if (cr_success == 0) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 10: Quintic (degree 5) curve, unsupported.
    nodes6 = 0
    call can_reduce( &
         6, 2, nodes6, cr_success)
    if (cr_success == -1) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_can_reduce

  subroutine test_full_reduce(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes1(2, 1), expected1(2, 1), reduced1(2, 1)
    real(c_double) :: nodes2(4, 2), expected2(4, 2), reduced2(4, 2)
    real(c_double) :: nodes3(6, 2), expected3(6, 2), reduced3(6, 2)
    integer(c_int) :: num_reduced_nodes
    logical(c_bool) :: not_implemented
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "full_reduce"

    ! CASE 1: Linear curve, one reduction.
    nodes1 = 5.5_dp
    expected1(1, :) = 5.5_dp
    call full_reduce( &
         2, 1, nodes1, num_reduced_nodes, &
         reduced1, not_implemented)
    if (num_reduced_nodes == 1 .AND. &
         all(reduced1(:1, :) == expected1(:1, :)) .AND. &
         .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 2: Cubic curve, one reduction.
    nodes2(1, :) = 0
    nodes2(2, :) = [2.0_dp, 4.0_dp]
    nodes2(3, :) = [4.0_dp, 6.0_dp]
    nodes2(4, :) = [6.0_dp, 6.0_dp]
    expected2(1, :) = 0
    expected2(2, :) = [3.0_dp, 6.0_dp]
    expected2(3, :) = [6.0_dp, 6.0_dp]
    call full_reduce( &
         4, 2, nodes2, num_reduced_nodes, &
         reduced2, not_implemented)
    if (num_reduced_nodes == 3 .AND. &
         all(reduced2(:3, :) == expected2(:3, :)) .AND. &
         .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Cubic curve, two reductions.
    nodes2(1, :) = [0.0_dp, 4.0_dp]
    nodes2(2, :) = [1.0_dp, 4.5_dp]
    nodes2(3, :) = [2.0_dp, 5.0_dp]
    nodes2(4, :) = [3.0_dp, 5.5_dp]
    expected2(1, :) = [0.0_dp, 4.0_dp]
    expected2(2, :) = [3.0_dp, 5.5_dp]
    call full_reduce( &
         4, 2, nodes2, num_reduced_nodes, &
         reduced2, not_implemented)
    if (num_reduced_nodes == 2 .AND. &
         all(reduced2(:2, :) == expected2(:2, :)) .AND. &
         .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 4: Cubic curve, no reductions.
    nodes2(1, :) = [0.0_dp, 2.0_dp]
    nodes2(2, :) = [-1.0_dp, 0.0_dp]
    nodes2(3, :) = 1
    nodes2(4, :) = [-0.75_dp, 1.625_dp]
    expected2 = nodes2
    call full_reduce( &
         4, 2, nodes2, num_reduced_nodes, &
         reduced2, not_implemented)
    if (num_reduced_nodes == 4 .AND. &
         all(reduced2(:4, :) == expected2(:4, :)) .AND. &
         .NOT. not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 5: Unsupported degree (quintic, degre 5).
    nodes3 = 0
    call full_reduce( &
         6, 2, nodes3, num_reduced_nodes, &
         reduced3, not_implemented)
    if (not_implemented) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_full_reduce

  subroutine test_compute_length(success)
    logical(c_bool), intent(inout) :: success
    ! Variables outside of signature.
    real(c_double) :: nodes1(2, 2), nodes2(3, 2), nodes3(4, 2)
    real(c_double) :: length, expected
    integer(c_int) :: error_val
    integer :: case_id
    character(:), allocatable :: name

    case_id = 1
    name = "compute_length"

    ! CASE 1: Linear curve.
    nodes1(1, :) = 0
    nodes1(2, :) = [3.0_dp, 4.0_dp]
    call compute_length( &
         2, 2, nodes1, length, error_val)
    if (length == 5.0_dp .AND. error_val == 0) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 1: Quadratic curve.
    nodes2(1, :) = 0
    nodes2(2, :) = [1.0_dp, 2.0_dp]
    nodes2(3, :) = [2.0_dp, 0.0_dp]
    call compute_length( &
         3, 2, nodes2, length, error_val)
    ! 2 INT_0^1 SQRT(16 s^2  - 16 s + 5) ds = SQRT(5) + sinh^{-1}(2)/2
    expected = sqrt(5.0_dp) + 0.5_dp * asinh(2.0_dp)
    if (abs(length - expected) <= spacing(expected) .AND. &
         error_val == 0) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

    ! CASE 3: Cubic curve.
    nodes3(1, :) = 0
    nodes3(2, :) = [1.0_dp, 2.0_dp]
    nodes3(3, :) = [2.0_dp, 0.0_dp]
    nodes3(4, :) = [3.5_dp, 0.0_dp]
    call compute_length( &
         4, 2, nodes3, length, error_val)
    ! x(s) = s (s^2 + 6) / 2
    ! y(s) = 6 s (s - 1)^2
    ! x'(s)^2 + y'(s)^2 = (9/4)(145s^4 - 384s^3 + 356s^2 - 128s + 20)
    ! NOTE: This "literal" has more precision than the type.
    expected = 4.0916195514424730685_dp
    if (abs(length - expected) <= spacing(expected) .AND. &
         error_val == 0) then
       call print_status(name, case_id, .TRUE.)
    else
       call print_status(name, case_id, .FALSE.)
       success = .FALSE.
    end if

  end subroutine test_compute_length

end module test_curve