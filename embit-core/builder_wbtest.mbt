///|
/// embit-core RobotBuilder 白盒测试。

///|
/// RobotBuilder 可被构造。
test "RobotBuilder - constructable" {
  let _ = RobotBuilder::{ _sealed: () }
}

///|
/// 12-DOF 人形机器人应有 12 个关节和 2 个传感器。
test "RobotBuilder - humanoid_12dof" {
  let model = RobotBuilder::humanoid_12dof()
  assert_eq(model.joints.length(), 12)
  assert_eq(model.sensors.length(), 2)
  assert_true(model.urdf_path.contains("humanoid"))
  // 检查关节名
  assert_eq(model.joints[0].name, "left_hip_yaw")
  assert_eq(model.joints[6].name, "right_hip_yaw")
  // 安全限幅
  assert_eq(model.limits.max_joint_velocity, 2.0)
}

///|
/// 12-DOF 四足机器人应有 12 个关节和 2 个传感器。
test "RobotBuilder - quadruped_12dof" {
  let model = RobotBuilder::quadruped_12dof()
  assert_eq(model.joints.length(), 12)
  assert_eq(model.sensors.length(), 2)
  assert_true(model.urdf_path.contains("quadruped"))
  // 检查关节名
  assert_eq(model.joints[0].name, "fl_hip")
  assert_eq(model.joints[3].name, "fr_hip")
  assert_eq(model.limits.max_joint_velocity, 3.0)
}

///|
/// 6-DOF 机械臂应有 6 个关节和 1 个传感器。
test "RobotBuilder - arm_6dof" {
  let model = RobotBuilder::arm_6dof()
  assert_eq(model.joints.length(), 6)
  assert_eq(model.sensors.length(), 1)
  assert_eq(model.joints[0].name, "joint1")
  assert_eq(model.joints[5].name, "joint6")
  assert_eq(model.limits.max_joint_effort, 20.0)
}

///|
/// 14-DOF 双臂机器人应有 14 个关节和 4 个传感器。
test "RobotBuilder - dual_arm_14dof" {
  let model = RobotBuilder::dual_arm_14dof()
  assert_eq(model.joints.length(), 14)
  assert_eq(model.sensors.length(), 4)
  assert_eq(model.joints[0].name, "left_arm_joint1")
  assert_eq(model.joints[7].name, "right_arm_joint1")
}

///|
/// 移动底盘应有 2 个关节和 2 个传感器。
test "RobotBuilder - mobile_base" {
  let model = RobotBuilder::mobile_base()
  assert_eq(model.joints.length(), 2)
  assert_eq(model.sensors.length(), 2)
  assert_eq(model.joints[0].name, "linear_x")
  assert_eq(model.joints[1].name, "angular_z")
  // angular_z 应为连续关节
  assert_eq(model.joints[1].joint_type, Continuous)
}

///|
/// to_info 应正确创建 RobotModelInfo。
test "RobotModel - to_info" {
  let model = RobotBuilder::arm_6dof()
  let info = model.to_info("arm6dof", "1.0")
  assert_eq(info.name, "arm6dof")
  assert_eq(info.version, "1.0")
  assert_eq(info.dof, 6)
  assert_eq(info.urdf_path, "models/arm_6dof.urdf")
}
