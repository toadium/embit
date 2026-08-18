///|
/// PID 控制器：比例-积分-微分控制器。
///
/// 用于关节级闭环控制，将目标位置与实际位置的误差映射为控制力矩。
/// 支持输出限幅与积分抗饱和（clamping）。
///
/// # Example
/// ```mbt check
/// test {
///   let pid = @embit-control.PIDController::new(1.0, 0.0, 0.0)
///   let output = pid.update(0.0, 0.1, 0.01)
///   inspect(output, content="-0.1")
/// }
/// ```
pub struct PIDController {
  kp : Double // 比例增益
  ki : Double // 积分增益
  kd : Double // 微分增益
  mut integral : Double // 积分项累计值
  mut prev_error : Double // 上一次误差（用于微分计算）
  mut prev_measurement : Double // 上一次测量值（用于微分基于测量值）
  mut output_min : Double? // 输出下限
  mut output_max : Double? // 输出上限
  mut first_update : Bool // 是否为首次更新
}

///|
/// 创建 PID 控制器。
///
/// `kp` / `ki` / `kd` 分别为比例、积分、微分增益。
pub fn PIDController::new(
  kp : Double,
  ki : Double,
  kd : Double,
) -> PIDController {
  {
    kp,
    ki,
    kd,
    integral: 0.0,
    prev_error: 0.0,
    prev_measurement: 0.0,
    output_min: None,
    output_max: None,
    first_update: true,
  }
}

///|
/// PID 控制步进：计算控制输出。
///
/// `setpoint` 为目标值，`measurement` 为当前测量值，`dt` 为时间间隔（秒）。
/// 返回控制输出（力矩/速度等），已应用输出限幅。
pub fn PIDController::update(
  self : PIDController,
  setpoint : Double,
  measurement : Double,
  dt : Double,
) -> Double {
  let error = setpoint - measurement
  // 积分项（梯形积分）
  if dt > 0.0 {
    self.integral = self.integral + error * dt
  }
  // 微分项（基于测量值变化，避免 setpoint 突变引发微分冲击）
  let derivative = if self.first_update || dt <= 0.0 {
    0.0
  } else {
    (measurement - self.prev_measurement) / dt
  }
  self.first_update = false
  self.prev_error = error
  self.prev_measurement = measurement
  // PID 输出
  let output = self.kp * error + self.ki * self.integral - self.kd * derivative
  // 输出限幅 + 积分抗饱和
  let clamped = self.clamp_output(output)
  if clamped != output {
    // 输出饱和时回退积分项，防止积分饱和
    if dt > 0.0 {
      self.integral = self.integral - error * dt
    }
  }
  clamped
}

///|
/// 输出限幅。
fn PIDController::clamp_output(self : PIDController, output : Double) -> Double {
  let mut result = output
  match self.output_min {
    Some(min) => if result < min { result = min }
    None => ()
  }
  match self.output_max {
    Some(max) => if result > max { result = max }
    None => ()
  }
  result
}

///|
/// 设置输出限幅。
pub fn PIDController::set_output_limits(
  self : PIDController,
  min : Double,
  max : Double,
) -> Unit {
  self.output_min = Some(min)
  self.output_max = Some(max)
}

///|
/// 重置控制器状态（积分项与微分项清零）。
pub fn PIDController::reset(self : PIDController) -> Unit {
  self.integral = 0.0
  self.prev_error = 0.0
  self.prev_measurement = 0.0
  self.first_update = true
}

///|
/// 获取当前积分项值。
pub fn PIDController::get_integral(self : PIDController) -> Double {
  self.integral
}

///|
/// 获取上次误差。
pub fn PIDController::get_error(self : PIDController) -> Double {
  self.prev_error
}

///|
/// 获取比例增益。
pub fn PIDController::get_kp(self : PIDController) -> Double {
  self.kp
}

///|
/// 获取积分增益。
pub fn PIDController::get_ki(self : PIDController) -> Double {
  self.ki
}

///|
/// 获取微分增益。
pub fn PIDController::get_kd(self : PIDController) -> Double {
  self.kd
}
