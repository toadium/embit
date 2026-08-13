///|
/// 阻抗控制器：弹簧-阻尼模型实现力位混合控制。
///
/// 阻抗控制将机器人与环境交互建模为质量-弹簧-阻尼系统：
/// `F = K * (x_d - x) + D * (v_d - v) + F_feedforward`
///
/// - `K`（刚度）：位置跟踪刚度，越大跟踪越准但交互力越大
/// - `D`（阻尼）：速度阻尼，抑制振荡，通常 D = 2 * sqrt(M * K)（临界阻尼）
/// - `M`（虚拟质量）：惯性，影响响应速度
///
/// 适用于接触操作（擦拭、装配、人机协作等）场景。
pub struct ImpedanceController {
  stiffness : Double // K：刚度（N/m 或 N·m/rad）
  damping : Double // D：阻尼（N·s/m 或 N·m·s/rad）
  mut desired_pos : Double // x_d：期望位置
  mut desired_vel : Double // v_d：期望速度
  mut ff_force : Double // 前馈力/力矩
}

///|
/// 创建阻抗控制器。
///
/// `stiffness` 为刚度 K，`damping` 为阻尼 D。
/// 临界阻尼建议 `D = 2 * sqrt(M * K)`。
pub fn ImpedanceController::new(
  stiffness : Double,
  damping : Double,
) -> ImpedanceController {
  { stiffness, damping, desired_pos: 0.0, desired_vel: 0.0, ff_force: 0.0 }
}

///|
/// 设置期望位置与速度。
pub fn ImpedanceController::set_target(
  self : ImpedanceController,
  pos : Double,
  vel : Double,
) -> Unit {
  self.desired_pos = pos
  self.desired_vel = vel
}

///|
/// 设置前馈力/力矩。
///
/// 用于补偿重力、摩擦等已知外力。
pub fn ImpedanceController::set_feedforward(
  self : ImpedanceController,
  force : Double,
) -> Unit {
  self.ff_force = force
}

///|
/// 计算控制输出力/力矩。
///
/// `current_pos` 为当前关节位置，`current_vel` 为当前关节速度。
/// 返回应施加的力/力矩。
pub fn ImpedanceController::compute(
  self : ImpedanceController,
  current_pos : Double,
  current_vel : Double,
) -> Double {
  let pos_error = self.desired_pos - current_pos
  let vel_error = self.desired_vel - current_vel
  self.stiffness * pos_error + self.damping * vel_error + self.ff_force
}

///|
/// 获取期望位置。
pub fn ImpedanceController::get_desired_pos(
  self : ImpedanceController,
) -> Double {
  self.desired_pos
}

///|
/// 获取期望速度。
pub fn ImpedanceController::get_desired_vel(
  self : ImpedanceController,
) -> Double {
  self.desired_vel
}

///|
/// 计算临界阻尼系数。
///
/// `D = 2 * sqrt(M * K)`，使系统无振荡最快收敛。
pub fn ImpedanceController::critical_damping(
  mass : Double,
  stiffness : Double,
) -> Double {
  2.0 * (mass * stiffness).sqrt()
}
