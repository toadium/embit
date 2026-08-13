///|
/// embit-control 传感器融合白盒测试。

///|
/// 浮点近似比较阈值。
let fusion_eps : Double = 0.001

///|
fn assert_fusion_approx(a : Double, b : Double) -> Unit raise {
  assert_true((a - b).abs() < fusion_eps)
}

///|
/// 新创建的融合器应初始状态为零。
test "SensorFusion - new initializes to zero" {
  let sf = SensorFusion::new(0.98)
  assert_eq(sf.get_orientation(), 0.0)
  assert_eq(sf.get_velocity(), 0.0)
  assert_eq(sf.get_bias(), 0.0)
  assert_eq(sf.update_count(), 0)
}

///|
/// 静止时更新应保持姿态不变。
test "SensorFusion - stationary update" {
  let sf = SensorFusion::new(0.98)
  sf.update(0.0, 0.0, 0.01)
  assert_fusion_approx(sf.get_orientation(), 0.0)
  assert_eq(sf.update_count(), 1)
}

///|
/// 陀螺仪积分应正确累积角度。
test "SensorFusion - gyro integration" {
  let sf = SensorFusion::new(1.0) // 纯陀螺仪
  // 10 rad/s 持续 0.1s → 1.0 rad
  for _ in 0..<10 {
    sf.update(10.0, 0.0, 0.01)
  }
  assert_fusion_approx(sf.get_orientation(), 1.0)
}

///|
/// 加速度计修正应拉向 accel_angle。
test "SensorFusion - accel correction" {
  let sf = SensorFusion::new(0.0) // 纯加速度计
  sf.update(0.0, 0.5, 0.01)
  assert_fusion_approx(sf.get_orientation(), 0.5)
}

///|
/// 零偏校准应减小静止陀螺仪读数的影响。
test "SensorFusion - bias calibration" {
  let sf = SensorFusion::new(0.98)
  // 模拟静止时陀螺仪有 0.1 rad/s 零偏
  for _ in 0..<100 {
    sf.calibrate_bias(0.1, 0.1)
  }
  assert_fusion_approx(sf.get_bias(), 0.1)
}

///|
/// reset 应清零所有状态。
test "SensorFusion - reset" {
  let sf = SensorFusion::default()
  sf.update(1.0, 0.5, 0.01)
  sf.reset()
  assert_eq(sf.get_orientation(), 0.0)
  assert_eq(sf.update_count(), 0)
}

///|
/// estimate_velocity 差分法。
test "SensorFusion - estimate_velocity" {
  let v = SensorFusion::estimate_velocity(1.0, 0.5, 0.1)
  assert_fusion_approx(v, 5.0) // (1.0 - 0.5) / 0.1 = 5.0
}

///|
/// estimate_velocity 零时间步返回 0。
test "SensorFusion - estimate_velocity zero dt" {
  let v = SensorFusion::estimate_velocity(1.0, 0.0, 0.0)
  assert_eq(v, 0.0)
}

///|
/// lowpass_filter 应平滑数据。
test "SensorFusion - lowpass_filter" {
  // 截止频率 10Hz，采样 100Hz，当前值 1.0，上次滤波 0.0
  let filtered = SensorFusion::lowpass_filter(10.0, 0.01, 1.0, 0.0)
  // 应介于 0 和 1 之间
  assert_true(filtered > 0.0)
  assert_true(filtered < 1.0)
}
