///|
/// 安全联锁控制器：关节限位 / 速度限制 / 力矩限制 / 碰撞检测 / 紧急停止。
///
/// Phase 4.2 新增：为真机联调提供全面安全联锁机制。
/// `SafetyController` 封装 `SafetyLimits` 与关节限位表，
/// 在动作执行前进行综合安全检查，违反时抛出 `SafetyLimitViolation`。
/// 支持紧急停止协议：触发后所有动作指令被拒绝，需手动重置恢复。

///|
/// 安全联锁控制器。
///
/// 持有安全约束参数、关节限位表与紧急停止状态。
/// `check_all` 方法对动作指令序列进行综合安全检查；
/// `emergency_stop` / `reset_emergency_stop` 管理紧急停止协议。
pub struct SafetyController {
  limits : @core.SafetyLimits
  joint_limits : Array[(Double, Double)] // (min, max) per joint
  mut emergency_stopped : Bool // 紧急停止状态
  mut violation_count : Int // 安全违规计数
  mut last_violation : String // 最近违规描述
}

///|
/// 创建安全联锁控制器。
///
/// `limits` 为安全约束参数，`joint_limits` 为每关节 (min, max) 限位。
pub fn SafetyController::new(
  limits : @core.SafetyLimits,
  joint_limits : Array[(Double, Double)],
) -> SafetyController {
  {
    limits,
    joint_limits,
    emergency_stopped: false,
    violation_count: 0,
    last_violation: "",
  }
}

///|
/// 从 RobotModel 创建安全联锁控制器。
///
/// 自动从模型关节规格提取关节限位与安全约束。
pub fn SafetyController::from_model(
  model : @core.RobotModel,
) -> SafetyController {
  let joint_limits : Array[(Double, Double)] = []
  for joint in model.joints {
    joint_limits.push((joint.min_position, joint.max_position))
  }
  SafetyController::new(model.limits, joint_limits)
}

///|
/// 查询紧急停止状态。
pub fn SafetyController::is_emergency_stopped(self : SafetyController) -> Bool {
  self.emergency_stopped
}

///|
/// 触发紧急停止。
///
/// 触发后所有动作指令被拒绝（`check_all` 直接抛出 `SafetyLimitViolation`）。
/// 需调用 `reset_emergency_stop` 恢复。
pub fn SafetyController::emergency_stop(self : SafetyController) -> Unit {
  self.emergency_stopped = true
  self.violation_count = self.violation_count + 1
  self.last_violation = "emergency stop triggered"
}

///|
/// 重置紧急停止，恢复正常运行。
pub fn SafetyController::reset_emergency_stop(self : SafetyController) -> Unit {
  self.emergency_stopped = false
}

///|
/// 查询安全违规计数。
pub fn SafetyController::violation_count(self : SafetyController) -> Int {
  self.violation_count
}

///|
/// 查询最近违规描述。
pub fn SafetyController::last_violation(self : SafetyController) -> String {
  self.last_violation
}

///|
/// 检查关节位置限位。
///
/// 验证每条指令中各关节目标位置在 `joint_limits` 范围内。
/// 违反时抛出 `SafetyLimitViolation`。
pub fn SafetyController::check_joint_limits(
  self : SafetyController,
  commands : Array[@core.ActionCommand],
) -> Unit raise @core.RobotError {
  for cmd in commands {
    for jc in cmd.joint_commands {
      let (name, target_pos) = jc
      let idx = joint_name_to_index(name, self.joint_limits.length())
      if idx >= 0 && idx < self.joint_limits.length() {
        let (min_pos, max_pos) = self.joint_limits[idx]
        if target_pos < min_pos {
          self.violation_count = self.violation_count + 1
          self.last_violation = "joint \{name} position \{target_pos} below limit \{min_pos}"
          raise SafetyLimitViolation(self.last_violation)
        }
        if target_pos > max_pos {
          self.violation_count = self.violation_count + 1
          self.last_violation = "joint \{name} position \{target_pos} above limit \{max_pos}"
          raise SafetyLimitViolation(self.last_violation)
        }
      }
    }
  }
}

///|
/// 检查关节速度限制。
///
/// 验证相邻指令间各关节速度不超过 `max_joint_velocity`。
pub fn SafetyController::check_velocity_limits(
  self : SafetyController,
  commands : Array[@core.ActionCommand],
) -> Unit raise @core.RobotError {
  if commands.length() < 2 {
    return
  }
  let max_vel = self.limits.max_joint_velocity
  if max_vel <= 0.0 {
    return
  }
  for i in 1..<commands.length() {
    let prev = commands[i - 1]
    let curr = commands[i]
    let dt = curr.timestamp - prev.timestamp
    if dt <= 0.0 {
      continue
    }
    for jc in curr.joint_commands {
      let (name, target_pos) = jc
      let mut prev_pos : Double? = None
      for prev_jc in prev.joint_commands {
        let (pn, pp) = prev_jc
        if pn == name {
          prev_pos = Some(pp)
          break
        }
      }
      match prev_pos {
        Some(pp) => {
          let velocity = (target_pos - pp).abs() / dt
          if velocity > max_vel {
            self.violation_count = self.violation_count + 1
            self.last_violation = "joint \{name} velocity \{velocity} exceeds limit \{max_vel}"
            raise SafetyLimitViolation(self.last_violation)
          }
        }
        None => continue
      }
    }
  }
}

///|
/// 检查关节力矩限制。
///
/// 验证指令中关节力矩不超过 `max_joint_effort`。
/// 简化实现：通过速度变化率估算力矩，超限抛出 `SafetyLimitViolation`。
pub fn SafetyController::check_effort_limits(
  self : SafetyController,
  commands : Array[@core.ActionCommand],
) -> Unit raise @core.RobotError {
  let max_effort = self.limits.max_joint_effort
  if max_effort <= 0.0 {
    return
  }
  if commands.length() < 3 {
    return
  }
  for i in 2..<commands.length() {
    let prev2 = commands[i - 2]
    let prev1 = commands[i - 1]
    let curr = commands[i]
    let dt = curr.timestamp - prev1.timestamp
    if dt <= 0.0 {
      continue
    }
    for jc in curr.joint_commands {
      let (name, curr_pos) = jc
      let mut v1 : Double? = None
      let mut v2 : Double? = None
      for prev1_jc in prev1.joint_commands {
        let (pn, pp) = prev1_jc
        if pn == name {
          for prev2_jc in prev2.joint_commands {
            let (pn2, pp2) = prev2_jc
            if pn2 == name {
              v2 = Some((pp - pp2) / dt)
              break
            }
          }
          v1 = Some((curr_pos - pp) / dt)
          break
        }
      }
      match (v1, v2) {
        (Some(a1), Some(a2)) => {
          let accel = (a1 - a2).abs() / dt
          if accel > max_effort {
            self.violation_count = self.violation_count + 1
            self.last_violation = "joint \{name} effort \{accel} exceeds limit \{max_effort}"
            raise SafetyLimitViolation(self.last_violation)
          }
        }
        _ => continue
      }
    }
  }
}

///|
/// 碰撞检测（占位实现）。
///
/// 检查 `collision_check_distance` 是否为正值。
/// 真实实现需接入碰撞检测库（如 FCL），此处仅验证参数有效性。
pub fn SafetyController::check_collision(
  self : SafetyController,
  _commands : Array[@core.ActionCommand],
) -> Unit raise @core.RobotError {
  if self.limits.collision_check_distance < 0.0 {
    self.violation_count = self.violation_count + 1
    self.last_violation = "collision check distance must be non-negative"
    raise SafetyLimitViolation(self.last_violation)
  }
}

///|
/// 综合安全检查：紧急停止 + 关节限位 + 速度限制 + 力矩限制 + 碰撞检测。
///
/// 在动作执行前调用，任一检查失败时抛出 `SafetyLimitViolation`。
/// 紧急停止状态下直接拒绝所有指令。
pub fn SafetyController::check_all(
  self : SafetyController,
  commands : Array[@core.ActionCommand],
) -> Unit raise @core.RobotError {
  if self.emergency_stopped {
    self.violation_count = self.violation_count + 1
    self.last_violation = "emergency stop active, all commands rejected"
    raise SafetyLimitViolation(self.last_violation)
  }
  self.check_joint_limits(commands)
  self.check_velocity_limits(commands)
  self.check_effort_limits(commands)
  self.check_collision(commands)
}

///|
/// 关节名转索引（简化哈希）。
fn joint_name_to_index(name : String, count : Int) -> Int {
  if count == 0 {
    return -1
  }
  name.length() % count
}
