///|
test "JointState construction and equality" {
  let j1 = JointState::{
    name: "shoulder",
    position: 0.0,
    velocity: 0.1,
    effort: 0.5,
  }
  let j2 = JointState::{
    name: "shoulder",
    position: 0.0,
    velocity: 0.1,
    effort: 0.5,
  }
  let j3 = JointState::{
    name: "elbow",
    position: 0.0,
    velocity: 0.1,
    effort: 0.5,
  }
  assert_eq(j1, j2)
  assert_true(j1 != j3)
}

///|
test "SensorType variants are distinct" {
  assert_true(SensorType::Camera != Lidar)
  assert_true(SensorType::Camera != Imu)
  assert_true(SensorType::Camera != JointEncoder)
  assert_true(SensorType::Lidar != Imu)
  assert_true(SensorType::Imu != JointEncoder)
}

///|
test "SensorReading construction" {
  let reading = SensorReading::{ kind: Camera, timestamp: 1.5, data: b"raw" }
  assert_eq(reading.kind, Camera)
  assert_eq(reading.timestamp, 1.5)
  assert_eq(reading.data, b"raw")
}

///|
test "ActionCommand construction" {
  let cmd = ActionCommand::{
    joint_commands: [("joint1", 0.5), ("joint2", 1.0)],
    timestamp: 2.0,
  }
  assert_eq(cmd.joint_commands.length(), 2)
  assert_eq(cmd.joint_commands[0], ("joint1", 0.5))
  assert_eq(cmd.timestamp, 2.0)
}
