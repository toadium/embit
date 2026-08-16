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
  assert_true(actions.length() > 0) // 指令解析生成非空动作序列
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

// ===== Phase 4.1 仿真集成测试 =====

///|
/// 仿真场景搭建 Demo 应完整执行无异常。
test "integration - sim_scene_setup_demo runs successfully" {
  sim_scene_setup_demo()
}

///|
/// 仿真闭环 Demo 应完整执行 100 步无异常。
test "integration - sim_closed_loop_demo runs 100 steps" {
  sim_closed_loop_demo()
}

///|
/// VLA 仿真执行 Demo 应完整执行多步推理无异常。
test "integration - vla_sim_execution_demo runs successfully" {
  vla_sim_execution_demo()
}

///|
/// 多机型场景管理 Demo 应完整执行无异常。
test "integration - multi_robot_scenario_demo runs successfully" {
  multi_robot_scenario_demo()
}

// ===== Phase 4.2 真机联调测试 =====

///|
/// 真机控制 Demo 应完整执行无异常。
test "integration - real_robot_demo runs successfully" {
  real_robot_demo()
}

///|
/// Sim2Real 一致性 Demo 应完整执行无异常。
test "integration - sim2real_consistency_demo runs successfully" {
  sim2real_consistency_demo()
}

///|
/// 安全联锁 Demo 应完整执行无异常。
test "integration - safety_interlock_demo runs successfully" {
  safety_interlock_demo()
}

///|
/// 紧急停止 Demo 应完整执行无异常。
test "integration - emergency_stop_demo runs successfully" {
  emergency_stop_demo()
}

///|
/// RealRobot 应正确实现 Robot trait。
test "RealRobot - implements Robot trait" {
  let model_info = @core.RobotModelInfo::{
    name: "test_robot",
    version: "1.0",
    dof: 6,
    urdf_path: "models/test.urdf",
  }
  let robot = @core.RealRobot::connect("can0", model_info)
  assert_true(robot.is_connected())
  let info = robot.get_model_info()
  assert_eq(info.name, "test_robot")
  assert_eq(info.dof, 6)
  let readings = robot.get_sensor_readings()
  assert_eq(readings.length(), 0)
  robot.disconnect()
  assert_false(robot.is_connected())
}

///|
/// RealRobot 紧急停止应拒绝动作。
test "RealRobot - emergency stop rejects actions" {
  let model_info = @core.RobotModelInfo::{
    name: "test",
    version: "1.0",
    dof: 6,
    urdf_path: "",
  }
  let robot = @core.RealRobot::connect("can0", model_info)
  robot.emergency_stop()
  assert_true(robot.is_emergency_stopped())
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.5)], timestamp: 0.0 },
  ]
  try robot.execute_actions(commands) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("emergency"))
    _ => fail("expected SafetyLimitViolation")
  } noraise {
    _ => fail("expected SafetyLimitViolation")
  }
  assert_eq(robot.execution_count(), 0)
  robot.reset_emergency_stop()
  robot.execute_actions(commands)
  assert_eq(robot.execution_count(), 1)
}

///|
/// SafetyController 应检测速度超限。
test "SafetyController - detects velocity violation" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 1.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let safety = @control.SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 10.0)], timestamp: 0.01 },
  ]
  try safety.check_all(commands) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("velocity"))
    _ => fail("expected velocity violation")
  } noraise {
    _ => fail("expected velocity violation")
  }
  assert_true(safety.violation_count() > 0)
}

///|
/// SafetyController 紧急停止应拒绝所有指令。
test "SafetyController - emergency stop rejects all" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 1.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let safety = @control.SafetyController::new(limits, [])
  safety.emergency_stop()
  assert_true(safety.is_emergency_stopped())
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.1)], timestamp: 0.0 },
  ]
  try safety.check_all(commands) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("emergency"))
    _ => fail("expected e-stop violation")
  } noraise {
    _ => fail("expected e-stop violation")
  }
  safety.reset_emergency_stop()
  assert_false(safety.is_emergency_stopped())
  safety.check_all(commands)
}

// ===== Phase 5 生产硬化测试 =====

///|
/// 性能调优 Demo 应完整执行无异常。
test "integration - performance_tuning_demo runs successfully" {
  performance_tuning_demo()
}

///|
/// 监控告警 Demo 应完整执行无异常。
test "integration - monitoring_alert_demo runs successfully" {
  monitoring_alert_demo()
}

///|
/// 安全认证 Demo 应完整执行无异常。
test "integration - safety_certification_demo runs successfully" {
  safety_certification_demo()
}

///|
/// ControlLoopBenchmark 应正确测量控制环路性能。
test "ControlLoopBenchmark - measures loop performance" {
  let bench = @control.ControlLoopBenchmark::new(1000.0, 100)
  let pid = @control.PIDController::new(2.0, 0.5, 0.05)
  pid.set_output_limits(-5.0, 5.0)
  let mut pos = 0.0
  let result = bench.run(fn(_i) {
    let output = pid.update(1.0, pos, 0.001)
    pos = pos + output * 0.001
  })
  assert_eq(result.iterations, 100)
  assert_true(result.average_latency >= 0.0)
  assert_true(result.max_latency >= result.min_latency)
}

///|
/// AlertSystem 应正确检测多级告警。
test "AlertSystem - detects multi-level alerts" {
  let alert_system = @control.AlertSystem::new(2.0, 0.1, 0.1)
  // 正常值不告警
  alert_system.check_joint_velocity("j1", 1.0, 0.0)
  assert_eq(alert_system.alert_count(), 0)
  // 超限值告警
  alert_system.check_joint_velocity("j1", 3.0, 0.1)
  assert_true(alert_system.alert_count() > 0)
  // 严重超限触发 Critical
  alert_system.check_joint_velocity("j1", 5.0, 0.2)
  assert_true(alert_system.critical_count() > 0)
}

///|
/// CollisionDetector 应正确检测碰撞。
test "CollisionDetector - detects collisions" {
  let detector = @control.CollisionDetector::new(0.05)
  detector.add_obstacle(0.3, 0.2, 0.1)
  assert_eq(detector.obstacle_count(), 1)
  let result = detector.check_all()
  assert_false(result.self_collision)
  assert_false(result.environment_collision)
  detector.clear_obstacles()
  assert_eq(detector.obstacle_count(), 0)
}

///|
/// SafetyCertification 应生成 ISO 10218 合规报告。
test "SafetyCertification - generates ISO 10218 report" {
  let robot_model = @core.RobotBuilder::arm_6dof()
  let cert = @control.SafetyCertification::new(robot_model)
  let report = cert.certification_report(true, true, true)
  assert_eq(report.standard, "ISO 10218-1")
  assert_true(report.checks.length() > 0)
}
