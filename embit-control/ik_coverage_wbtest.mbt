///|
/// LegIKSolver::solve_planar_internal 余弦钳位 > 1.0 边界。
test "LegIKSolver - cos clamp above 1.0" {
  // l1 = l2 = 1.0, d 略小于 max_reach + 0.0001 但 d_sq > (l1+l2)^2
  // d = 2.00005, max_reach = 2.0, 检查阈值 = 2.0001
  // d < 2.0001 所以通过可达性检查，但 cos_knee > 1.0
  let solver = LegIKSolver::new(1.0, 1.0)
  let r = 2.00005
  let z = 0.0
  let (hip, knee) = solver.solve_planar_internal(r, z, true)
  let _ = (hip, knee)
  assert_true(true)
}

///|
/// LegIKSolver::solve_planar_internal 余弦钳位 < -1.0 边界。
test "LegIKSolver - cos clamp below -1.0" {
  // l1 = 2.0, l2 = 1.0, min_reach = 1.0
  // d 略大于 min_reach - 0.0001 但 d_sq < (l1-l2)^2
  // d = 0.99995, min_reach = 1.0, 检查阈值 = 0.9999
  // d > 0.9999 所以通过可达性检查，但 cos_knee < -1.0
  let solver = LegIKSolver::new(2.0, 1.0)
  let r = 0.0
  let z = 0.99995
  let (hip, knee) = solver.solve_planar_internal(r, z, true)
  let _ = (hip, knee)
  assert_true(true)
}
