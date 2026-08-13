///|
test "JointType variants are distinct" {
  assert_true(JointType::Revolute != Prismatic)
  assert_true(JointType::Continuous != Fixed)
}

///|
test "JointSpec construction" {
  let spec : JointSpec = {
    name: "shoulder",
    joint_type: Revolute,
    min_position: -3.14,
    max_position: 3.14,
    max_velocity: 2.0,
    max_effort: 100.0,
  }
  assert_eq(spec.name, "shoulder")
  assert_eq(spec.joint_type, Revolute)
  assert_eq(spec.max_velocity, 2.0)
}

///|
test "SensorSpec construction" {
  let spec : SensorSpec = {
    name: "camera0",
    sensor_type: Camera,
    topic: "/camera0/image",
  }
  assert_eq(spec.name, "camera0")
  assert_eq(spec.sensor_type, Camera)
  assert_eq(spec.topic, "/camera0/image")
}

///|
test "SafetyLimits construction" {
  let limits : SafetyLimits = {
    max_joint_velocity: 2.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  assert_eq(limits.max_joint_velocity, 2.0)
  assert_eq(limits.collision_check_distance, 0.01)
}

///|
test "RobotModel construction" {
  let model : RobotModel = {
    urdf_path: "models/t800.urdf",
    joints: [
      {
        name: "j1",
        joint_type: Revolute,
        min_position: -1.0,
        max_position: 1.0,
        max_velocity: 2.0,
        max_effort: 50.0,
      },
    ],
    sensors: [{ name: "cam", sensor_type: Camera, topic: "/cam" }],
    limits: {
      max_joint_velocity: 2.0,
      max_joint_effort: 100.0,
      collision_check_distance: 0.01,
    },
  }
  assert_eq(model.urdf_path, "models/t800.urdf")
  assert_eq(model.joints.length(), 1)
  assert_eq(model.sensors.length(), 1)
}

///|
test "RobotModelInfo construction" {
  let info : RobotModelInfo = {
    name: "t800",
    version: "1.0",
    dof: 6,
    urdf_path: "models/t800.urdf",
  }
  assert_eq(info.name, "t800")
  assert_eq(info.dof, 6)
}
