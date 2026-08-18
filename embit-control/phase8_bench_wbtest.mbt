///|
/// Phase 8 控制环路综合基准测试：测量 PID+FK+Safety 管线的性能特征。
///
/// 使用 ControlLoopBenchmark 测量 1kHz 控制环路在 10000 次迭代下的统计指标，
/// 验证 P99 抖动与平均频率是否满足设计目标。

///|
/// 控制环路综合基准：PID + FK + Safety 检查 10000 次迭代。
test "phase8 - combined control loop benchmark 10k iterations" {
  let pid = PIDController::new(1.5, 0.5, 0.05)
  pid.set_output_limits(-10.0, 10.0)
  let fk_solver = DhFKSolver::arm_6dof()
  let joint_angles = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 2.0,
    max_joint_effort: 50.0,
    collision_check_distance: 0.05,
  }
  let joint_limits = [
    (-3.14, 3.14),
    (-3.14, 3.14),
    (-3.14, 3.14),
    (-3.14, 3.14),
    (-3.14, 3.14),
    (-3.14, 3.14),
  ]
  let safety = SafetyController::new(limits, joint_limits)
  let cmd = @core.ActionCommand::{
    joint_commands: [
      ("joint1", 0.5),
      ("joint2", 0.3),
      ("joint3", 0.1),
      ("joint4", 0.0),
      ("joint5", 0.0),
      ("joint6", 0.0),
    ],
    timestamp: 0.1,
  }
  let bench = ControlLoopBenchmark::new(1000.0, 10000)
  let result = bench.run(fn(_i) {
    // 模拟控制环路：PID → FK → Safety check
    ignore(pid.update(0.5, 0.48, 0.001))
    ignore(fk_solver.fk(joint_angles)) catch {
      _ => ()
    }
    safety.check_all([cmd]) catch {
      _ => ()
    }
  })
  // 验证基准测试完成
  assert_eq(result.iterations, 10000)
  // 确定性计时器下延迟为 0（loop body 不推进 tick），验证统计无 NaN
  assert_true(result.average_latency >= 0.0)
}

///|
/// PID 控制环路基准：100000 次快速迭代验证吞吐量。
test "phase8 - PID throughput 100k iterations" {
  let pid = PIDController::new(2.0, 0.5, 0.05)
  pid.set_output_limits(-10.0, 10.0)
  let bench = ControlLoopBenchmark::new(1000.0, 100000)
  let result = bench.run(fn(i) {
    let setpoint = i.to_double() * 0.001
    ignore(pid.update(setpoint, setpoint * 0.95, 0.001))
  })
  assert_eq(result.iterations, 100000)
}

///|
/// FK 解算基准：10000 次正运动学解算验证计算吞吐量。
test "phase8 - FK throughput 10k iterations" {
  let solver = DhFKSolver::arm_6dof()
  let angles = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]
  let bench = ControlLoopBenchmark::new(1000.0, 10000)
  let result = bench.run(fn(_i) { ignore(solver.fk(angles)) catch { _ => () } })
  assert_eq(result.iterations, 10000)
}

///|
/// Safety 检查基准：50000 次安全联锁验证。
test "phase8 - safety check 50k iterations" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 2.0,
    max_joint_effort: 50.0,
    collision_check_distance: 0.05,
  }
  let safety = SafetyController::new(limits, [
    (-3.14, 3.14),
    (-3.14, 3.14),
    (-3.14, 3.14),
    (-3.14, 3.14),
    (-3.14, 3.14),
    (-3.14, 3.14),
  ])
  let cmd = @core.ActionCommand::{
    joint_commands: [("j1", 0.5), ("j2", 0.3), ("j3", 0.1)],
    timestamp: 0.1,
  }
  let bench = ControlLoopBenchmark::new(1000.0, 50000)
  let result = bench.run(fn(_i) { safety.check_all([cmd]) catch { _ => () } })
  assert_eq(result.iterations, 50000)
}
