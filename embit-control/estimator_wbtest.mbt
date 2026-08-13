///|
/// embit-control 卡尔曼滤波与状态估计器白盒测试。

///|
/// 浮点近似比较阈值。
let kf_eps : Double = 0.01

///|
fn assert_kf_approx(a : Double, b : Double) -> Unit raise {
  assert_true((a - b).abs() < kf_eps)
}

///|
/// 卡尔曼滤波器：初始状态应为零。
test "KalmanFilter1D - initial state" {
  let kf = KalmanFilter1D::new(0.001, 0.01, 0.1)
  assert_eq(kf.get_pos(), 0.0)
  assert_eq(kf.get_vel(), 0.0)
  assert_true(kf.get_pos_uncertainty() > 0.0)
}

///|
/// 卡尔曼滤波器：with_initial 设置初始状态。
test "KalmanFilter1D - with_initial" {
  let kf = KalmanFilter1D::with_initial(1.5, 0.5, 0.001, 0.01, 0.1)
  assert_eq(kf.get_pos(), 1.5)
  assert_eq(kf.get_vel(), 0.5)
}

///|
/// 卡尔曼滤波器：静止观测应收敛到观测值。
test "KalmanFilter1D - converge to static measurement" {
  let kf = KalmanFilter1D::new(0.001, 0.01, 0.1)
  // 持续观测位置=1.0，应收敛到 1.0
  for _ in 0..<100 {
    kf.step(1.0, 0.01)
  }
  assert_kf_approx(kf.get_pos(), 1.0)
  assert_kf_approx(kf.get_vel(), 0.0)
}

///|
/// 卡尔曼滤波器：匀速运动应跟踪位置。
test "KalmanFilter1D - track constant velocity" {
  let kf = KalmanFilter1D::new(0.001, 0.01, 0.1)
  // 真实运动：pos = 2.0 * t, vel = 2.0
  let dt = 0.01
  let mut true_pos = 0.0
  for _ in 0..<200 {
    true_pos = true_pos + 2.0 * dt
    kf.step(true_pos, dt)
  }
  // 位置应接近真实位置
  assert_kf_approx(kf.get_pos(), true_pos)
  // 速度应接近 2.0
  assert_kf_approx(kf.get_vel(), 2.0)
}

///|
/// 卡尔曼滤波器：应抑制噪声。
test "KalmanFilter1D - noise suppression" {
  let kf = KalmanFilter1D::new(0.001, 0.01, 0.1)
  // 观测值在 1.0 附近抖动
  let noisy = [1.05, 0.95, 1.08, 0.92, 1.03, 0.97, 1.06, 0.94, 1.02, 0.98]
  for i in 0..<100 {
    let idx = i % 10
    kf.step(noisy[idx], 0.01)
  }
  // 滤波后应接近 1.0
  assert_kf_approx(kf.get_pos(), 1.0)
}

///|
/// 卡尔曼滤波器：predict 只前推状态不修正。
test "KalmanFilter1D - predict only" {
  let kf = KalmanFilter1D::with_initial(0.0, 1.0, 0.001, 0.01, 0.1)
  kf.predict(0.1)
  // pos = 0 + 1.0*0.1 = 0.1
  assert_kf_approx(kf.get_pos(), 0.1)
  // vel 不变
  assert_kf_approx(kf.get_vel(), 1.0)
}

///|
/// 卡尔曼滤波器：reset 清零状态。
test "KalmanFilter1D - reset" {
  let kf = KalmanFilter1D::with_initial(1.5, 0.5, 0.001, 0.01, 0.1)
  kf.reset()
  assert_eq(kf.get_pos(), 0.0)
  assert_eq(kf.get_vel(), 0.0)
}

///|
/// 状态估计器：直通模式向后兼容。
test "StateEstimator - passthrough mode" {
  let est = StateEstimator::new()
  assert_true(!est.is_kalman_enabled())
  let state : Array[@core.JointState] = [
    { name: "joint1", position: 1.0, velocity: 0.0, effort: 0.0 },
  ]
  est.set_state(state)
  let got = est.get_state()
  assert_eq(got.length(), 1)
  assert_eq(got[0].name, "joint1")
}

///|
/// 状态估计器：卡尔曼模式滤波。
test "StateEstimator - kalman mode filtering" {
  let est = StateEstimator::new_kalman(0.001, 0.01, 0.1)
  assert_true(est.is_kalman_enabled())
  // 模拟 50 步观测，位置=0.5
  for _ in 0..<50 {
    let observed : Array[@core.JointState] = [
      { name: "j1", position: 0.5, velocity: 0.0, effort: 0.0 },
    ]
    est.update_joints(observed, 0.01)
  }
  let state = est.get_state()
  assert_eq(state.length(), 1)
  assert_kf_approx(state[0].position, 0.5)
}

///|
/// 状态估计器：卡尔曼模式多关节独立滤波。
test "StateEstimator - kalman multi-joint" {
  let est = StateEstimator::new_kalman(0.001, 0.01, 0.1)
  for _ in 0..<50 {
    let observed : Array[@core.JointState] = [
      { name: "j1", position: 1.0, velocity: 0.0, effort: 0.0 },
      { name: "j2", position: -0.5, velocity: 0.0, effort: 0.0 },
    ]
    est.update_joints(observed, 0.01)
  }
  let state = est.get_state()
  assert_eq(state.length(), 2)
  assert_kf_approx(state[0].position, 1.0)
  assert_kf_approx(state[1].position, -0.5)
  // 滤波器应存在
  assert_true(est.get_filter("j1") is Some(_))
  assert_true(est.get_filter("j2") is Some(_))
}

///|
/// 状态估计器：reset 清零所有状态。
test "StateEstimator - reset" {
  let est = StateEstimator::new_kalman(0.001, 0.01, 0.1)
  let observed : Array[@core.JointState] = [
    { name: "j1", position: 1.0, velocity: 0.0, effort: 0.0 },
  ]
  est.update_joints(observed, 0.01)
  est.reset()
  assert_eq(est.get_state().length(), 0)
  assert_eq(est.last_update(), 0.0)
}

///|
/// 状态估计器：update 传感器读数更新时间戳。
test "StateEstimator - update sensor readings" {
  let est = StateEstimator::new()
  let readings : Array[@core.SensorReading] = [
    { kind: JointEncoder, timestamp: 1.5, data: b"" },
    { kind: JointEncoder, timestamp: 2.3, data: b"" },
  ]
  est.update(readings)
  assert_eq(est.last_update(), 2.3)
}
