///|
test "RobotError equality" {
  let e1 = RobotError::SafetyLimitViolation("velocity exceeded")
  let e2 = RobotError::SafetyLimitViolation("velocity exceeded")
  assert_eq(e1, e2)
}

///|
test "RobotError variants are distinct" {
  let e1 = RobotError::ConnectError("msg")
  let e2 = RobotError::SensorReadError("msg")
  assert_true(e1 != e2)
}

///|
fn raise_model_error() -> Unit raise RobotError {
  raise ModelLoadError("file not found")
}

///|
test "RobotError raise and catch" {
  try raise_model_error() catch {
    ModelLoadError(msg) => assert_eq(msg, "file not found")
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ModelLoadError to be raised")
  }
}
