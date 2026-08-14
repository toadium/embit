///|
/// embit-examples 集成测试：验证三类 Demo 端到端可运行。
///
/// 这些测试串联全部 6 个子模块，验证 Phase 1 框架完整性。
/// 运行于 native 后端（依赖 FFI）。

///|
/// 人形行走 Demo 应完整执行无异常。
test "integration - humanoid_walk runs successfully" {
  humanoid_walk()
}

///|
/// 四足避障 Demo 应完整执行无异常。
test "integration - quadruped_avoid runs successfully" {
  quadruped_avoid()
}

///|
/// 机械臂抓取 Demo 应完整执行无异常。
test "integration - arm_grasp runs successfully" {
  arm_grasp()
}

///|
/// 验证全链路数据流：仿真连接 → VLA 推理 → 轨迹规划 → 安全检查。
test "integration - full pipeline data flow" {
  // 1. 仿真连接
  let sim = @gazebo.GazeboClient::connect("localhost:9999")
  assert_true(sim.is_connected())

  // 2. VLA 模型加载与推理
  let model = @ggml.VlaModel::load("models/test.gguf")
  assert_true(model.is_loaded())
  let actions = model.infer(b"test_image", "test instruction")
  assert_eq(actions.length(), 0) // 占位返回空数组
  assert_eq(model.infer_count(), 1)

  // 3. 运动控制器与轨迹规划
  let robot_model = @core.RobotModel::{
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: {
      max_joint_velocity: 2.0,
      max_joint_effort: 50.0,
      collision_check_distance: 0.05,
    },
  }
  let ctrl = @control.MotionController::new(robot_model)
  ctrl.attach_simulation(sim)
  assert_true(ctrl.is_sim_attached())

  let start : Array[(String, Double)] = [("j1", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 1.0)]
  let constraints = @control.TrajectoryConstraints::{
    max_velocity: 2.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  let traj = ctrl.compute_trajectory(start, goal, constraints)
  assert_true(traj.length() > 1)

  // 4. 安全检查
  let commands = traj.to_commands()
  ctrl.check_safety(commands)

  // 5. 可视化面板
  let panel = @view.ViewPanel::with_model({
    name: "test",
    version: "1.0",
    dof: 1,
    urdf_path: "",
  })
  panel.add_widget({ widget_type: JointPlot, title: "Test", topic: "/test" })
  assert_eq(panel.widget_count(), 1)

  // 6. 录制与回放
  let recording = panel.record("integration_test")
  recording.add_frame()
  recording.add_frame()
  assert_eq(recording.frames(), 2)
  let stream = panel.playback(recording)
  assert_eq(stream.total_frames, 2)
  assert_eq(stream.next_frame(), 1)
  assert_eq(stream.next_frame(), 2)
  assert_true(stream.is_finished())

  // 7. 仿真发布
  sim.publish("/test_topic", b"test_data")
  assert_eq(sim.topic_count(), 1)

  // 8. 清理
  panel.stop_recording()
  model.free()
  sim.disconnect()
  assert_false(sim.is_connected())
}

///|
/// 验证 VLA 多后端切换与推理独立性。
test "integration - VLA backend switching" {
  let model = @ggml.VlaModel::load("models/test.gguf")
  let backends = @ggml.VlaModel::supported_backends()
  assert_eq(backends.length(), 3)

  // 默认 CPU
  assert_eq(model.get_backend(), Cpu)

  // 切换到 CUDA
  model.set_backend(Cuda)
  assert_eq(model.get_backend(), Cuda)

  // 切换到 Metal
  model.set_backend(Metal)
  assert_eq(model.get_backend(), Metal)

  // 切换回 CPU
  model.set_backend(Cpu)
  assert_eq(model.get_backend(), Cpu)

  model.free()
}

///|
/// VLA 推理管线 Demo 应完整执行无异常。
test "integration - vla_pipeline_demo runs successfully" {
  vla_pipeline_demo()
}

///|
/// 阻抗控制 Demo 应完整执行无异常。
test "integration - impedance_control_demo runs successfully" {
  impedance_control_demo()
}

///|
/// 传感器融合 Demo 应完整执行无异常。
test "integration - sensor_fusion_demo runs successfully" {
  sensor_fusion_demo()
}

///|
/// 批量推理 Demo 应完整执行无异常。
test "integration - batch_inference_demo runs successfully" {
  batch_inference_demo()
}

///|
/// 多机型场景管理 Demo 应完整执行无异常。
test "integration - multi_robot_scene_demo runs successfully" {
  multi_robot_scene_demo()
}

///|
/// 笛卡尔空间控制 Demo 应完整执行无异常。
test "integration - cartesian_control_demo runs successfully" {
  cartesian_control_demo()
}

///|
/// 验证 RobotBuilder 生成的机型模型关节数正确。
test "integration - RobotBuilder joint counts" {
  let humanoid = @core.RobotBuilder::humanoid_12dof()
  assert_eq(humanoid.joints.length(), 12)

  let quadruped = @core.RobotBuilder::quadruped_12dof()
  assert_eq(quadruped.joints.length(), 12)

  let arm = @core.RobotBuilder::arm_6dof()
  assert_eq(arm.joints.length(), 6)

  let dual_arm = @core.RobotBuilder::dual_arm_14dof()
  assert_eq(dual_arm.joints.length(), 14)

  let mobile = @core.RobotBuilder::mobile_base()
  assert_eq(mobile.joints.length(), 2)
}

///|
/// 验证 GazeboRobot 实现 Robot trait 接口。
test "integration - GazeboRobot implements Robot trait" {
  let sim = @gazebo.GazeboClient::connect("localhost:9020")
  let model_info = @core.RobotModelInfo::{
    name: "test_robot",
    version: "1.0",
    dof: 6,
    urdf_path: "models/test.urdf",
  }
  let robot = @gazebo.GazeboRobot::from_client(sim, model_info)
  // 验证 Robot trait 方法
  let info = robot.get_model_info()
  assert_eq(info.name, "test_robot")
  assert_eq(info.dof, 6)
  // 验证传感器读数（初始为空）
  let readings = robot.get_sensor_readings()
  assert_eq(readings.length(), 0)
  // 验证动作执行
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.5)], timestamp: 0.0 },
  ]
  robot.execute_actions(commands)
  // 验证连接状态
  assert_true(robot.is_connected())
  robot.disconnect()
  assert_false(robot.is_connected())
}

///|
/// 验证 JointGroup 关节分组管理。
test "integration - JointGroup management" {
  let group = @control.JointGroup::new("test_group", [
    "joint1", "joint2", "joint3",
  ])
  assert_eq(group.get_name(), "test_group")
  assert_eq(group.size(), 3)
  assert_true(group.contains("joint1"))
  assert_false(group.contains("joint4"))
  // 设置与获取位置
  group.set_position("joint1", 0.5)
  group.set_position("joint2", -0.3)
  assert_true((group.get_position("joint1") - 0.5).abs() < 0.001)
  assert_true((group.get_position("joint2") - -0.3).abs() < 0.001)
  // 批量设置
  group.set_positions([("joint1", 1.0), ("joint2", 2.0), ("joint3", 3.0)])
  let positions = group.get_positions()
  assert_eq(positions.length(), 3)
  // 重置
  group.reset()
  let reset_positions = group.get_positions()
  for i in 0..<reset_positions.length() {
    let (_, v) = reset_positions[i]
    assert_true(v.abs() < 0.001)
  }
}

///|
/// 验证 CartesianController 笛卡尔控制完整管线。
test "integration - CartesianController pipeline" {
  let ctrl = @control.SimpleCartesianController::new(6, "ee_link")
  // 验证属性
  assert_eq(ctrl.dof(), 6)
  assert_eq(ctrl.end_effector_name(), "ee_link")
  // 规划轨迹
  let start : @control.Pose = @control.Pose::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  let target : @control.Pose = @control.Pose::new(1.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  let traj = ctrl.move_to(start, target, 1.0, 0.1)
  assert_true(traj.length() > 1)
  // 转换为关节状态
  let joint_seqs = ctrl.to_joint_states(traj)
  assert_eq(joint_seqs.length(), traj.length())
  // 验证 FK 一致性
  let last_pose = ctrl.get_end_effector_pose(
    joint_seqs[joint_seqs.length() - 1],
  )
  let (lx, _, _) = last_pose.position
  assert_true((lx - 1.0).abs() < 0.001)
}

///|
/// 全栈综合 Demo 应完整执行无异常。
test "integration - full_stack_demo runs successfully" {
  full_stack_demo()
}

///|
/// 示例工程占位入口应完整执行无异常。
test "integration - demo_skeleton runs successfully" {
  demo_skeleton()
}
