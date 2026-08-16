///|
/// Embit Phase 5 生产硬化 Demo：性能调优 / 监控告警 / 安全认证。

///|
/// 性能调优 Demo：控制环路基准测试 + 抖动分析。
///
/// 演示 Phase 5.1：控制环路抖动测量与批处理推理。
pub fn performance_tuning_demo() -> Unit raise @core.RobotError {
  // 1. 控制环路基准测试（1000 次迭代，目标 1kHz）
  let bench = @control.ControlLoopBenchmark::new(1000.0, 100)
  let pid = @control.PIDController::new(2.0, 0.5, 0.05)
  pid.set_output_limits(-5.0, 5.0)
  let mut current_pos = 0.0
  let target_pos = 0.5
  let result = bench.run(fn(_i) {
    let output = pid.update(target_pos, current_pos, 0.001)
    current_pos = current_pos + output * 0.001
  })

  // 2. 查询基准结果
  let _iterations = result.iterations
  let _avg_latency = result.average_latency
  let _max_latency = result.max_latency
  let _jitter = result.jitter_p99
  let _freq = result.average_frequency

  // 3. 批量推理 Demo
  let model = @ggml.VlaModel::load("models/smolvla-1b-q4.gguf")
  let inputs : Array[(Bytes, String)] = [
    (b"img1", "walk forward"),
    (b"img2", "turn left"),
    (b"img3", "grasp object"),
  ]
  let config = @ggml.InferConfig::new(0.7, 40, 0.9, 256)
  let _results = model.batch_infer_with_config(inputs, config)
  model.free()
}

///|
/// 监控告警 Demo：AlertSystem 多级告警 + Selene 面板实时监控。
///
/// 演示 Phase 5.2：异常告警与全链路数据录制。
pub fn monitoring_alert_demo() -> Unit raise @core.RobotError {
  // 1. 创建告警系统
  let alert_system = @control.AlertSystem::default()

  // 2. 创建可视化面板
  let panel = @view.ViewPanel::with_model({
    name: "humanoid",
    version: "1.0",
    dof: 12,
    urdf_path: "models/humanoid.urdf",
  })
  panel.add_widget({
    widget_type: JointPlot,
    title: "Joint States",
    topic: "/joint_states",
  })
  panel.add_widget({
    widget_type: SensorDisplay,
    title: "Alerts",
    topic: "/alerts",
  })

  // 3. 模拟控制环路：检测异常并告警
  let timer = @core.Timer::start()
  let dt = 0.02
  let recording = panel.record("monitoring_session")

  for i in 0..<50 {
    timer.tick(dt)
    let t = timer.elapsed()

    // 模拟关节速度检测
    let velocity = if i < 30 { 1.0 } else { 3.0 }
    alert_system.check_joint_velocity("left_hip", velocity, t)

    // 模拟通信延迟检测
    let comm_latency = if i < 40 { 0.05 } else { 0.2 }
    alert_system.check_communication(comm_latency, t)

    // 模拟推理延迟检测
    let infer_latency = if i < 35 { 0.08 } else { 0.15 }
    alert_system.check_inference(infer_latency, t)

    // 推送数据到面板
    panel.push_data("joint_velocity", t, velocity)
    panel.render([{ name: "left_hip", position: 0.3, velocity, effort: 0.0 }])
  }

  // 4. 查询告警统计
  let _alert_count = alert_system.alert_count()
  let _critical_count = alert_system.critical_count()

  // 5. 停止录制
  recording.stop()
  panel.stop_recording()
}

///|
/// 安全认证 Demo：ISO 10218 合规检查 + 碰撞检测。
///
/// 演示 Phase 5.3：ISO 10218 工业机器人安全标准合规检查。
pub fn safety_certification_demo() -> Unit {
  // 1. 构建机器人模型
  let robot_model = @core.RobotBuilder::arm_6dof()

  // 2. 创建安全认证检查器
  let cert = @control.SafetyCertification::new(robot_model)

  // 3. 生成 ISO 10218 合规报告
  let report = cert.certification_report(true, true, true)

  // 4. 查询报告详情
  let _standard = report.standard
  let _passed = report.overall_passed
  for check in report.checks {
    let _name = check.name
    let _passed = check.passed
    let _detail = check.detail
  }

  // 5. 碰撞检测
  let collision = @control.CollisionDetector::new(0.05)
  collision.update_joints([("joint1", 0.0), ("joint2", 0.5)])
  collision.add_obstacle(0.3, 0.2, 0.1)
  let _result = collision.check_all()

  // 6. 查询碰撞检测器状态
  let _safety_dist = collision.safety_distance()
  let _obstacle_count = collision.obstacle_count()
}
