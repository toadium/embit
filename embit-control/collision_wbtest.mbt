///|
/// CollisionDetector::check_environment_collision 负安全距离 + 有障碍物。
test "CollisionDetector - environment collision negative distance" {
  let detector = CollisionDetector::new(-0.1)
  detector.add_obstacle(0.3, 0.2, 0.1)
  let result = detector.check_environment_collision()
  assert_true(result.environment_collision)
  assert_false(result.self_collision)
}
