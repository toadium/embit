///|
/// 轨迹规划约束参数。
///
/// 定义轨迹规划过程中的运动学约束，由 `MotionController::compute_trajectory` 使用。
pub(all) struct TrajectoryConstraints {
  max_velocity : Double // 最大关节速度（rad/s）
  max_acceleration : Double // 最大关节加速度（rad/s²）
  time_step : Double // 采样时间间隔（s）
} derive(Eq, Debug)

///|
/// 轨迹点：某一时刻各关节的目标位置。
///
/// `positions` 为关节名到目标角度的映射，`timestamp` 为该点的时间戳。
pub(all) struct Waypoint {
  positions : Array[(String, Double)]
  timestamp : Double
} derive(Eq, Debug)

///|
/// 轨迹：有序轨迹点序列。
///
/// 由 `compute_trajectory` 生成，由 `execute_trajectory` 执行。
/// `duration` 为轨迹总时长（秒），等于最后一个轨迹点的时间戳。
pub(all) struct Trajectory {
  waypoints : Array[Waypoint]
  duration : Double
} derive(Eq, Debug)

///|
/// 创建空轨迹。
pub fn Trajectory::empty() -> Trajectory {
  { waypoints: [], duration: 0.0 }
}

///|
/// 轨迹点数。
pub fn Trajectory::length(self : Trajectory) -> Int {
  self.waypoints.length()
}

///|
/// 将轨迹转换为动作指令序列。
///
/// 每个轨迹点映射为一条 `ActionCommand`，供 `Robot::execute_actions` 执行。
pub fn Trajectory::to_commands(self : Trajectory) -> Array[@core.ActionCommand] {
  self.waypoints.map(fn(wp) {
    { joint_commands: wp.positions, timestamp: wp.timestamp }
  })
}

///|
/// 平滑步进函数（smoothstep）：`3t² - 2t³`。
///
/// `t=0` 返回 0，`t=1` 返回 1，起止导数为零。
fn smoothstep(t : Double) -> Double {
  3.0 * t * t - 2.0 * t * t * t
}

///|
/// 融合两条轨迹：在 `blend_duration` 时间窗口内平滑过渡。
///
/// `first` 的末尾与 `second` 的起始之间插入平滑过渡段，
/// 使用 smoothstep 插值确保速度连续。
/// `blend_duration` 为过渡段时长（秒），必须大于 0。
/// 两条轨迹的关节集合应一致。
///
/// 返回融合后的轨迹，总时长 = `first.duration + blend_duration + second.duration`。
pub fn Trajectory::blend(
  first : Trajectory,
  second : Trajectory,
  blend_duration : Double,
) -> Trajectory raise @core.RobotError {
  if blend_duration <= 0.0 {
    raise InvalidConfig("blend_duration must be positive")
  }
  if first.length() == 0 || second.length() == 0 {
    raise InvalidConfig("cannot blend empty trajectories")
  }
  let result : Array[Waypoint] = []
  // 1. 添加 first 轨迹的所有点（时间不变）
  for wp in first.waypoints {
    result.push(wp)
  }
  // 2. 生成过渡段
  let first_end = first.waypoints[first.length() - 1]
  let second_start = second.waypoints[0]
  let blend_steps = (blend_duration / 0.01).ceil().to_int()
  let actual_steps = if blend_steps > 1 { blend_steps } else { 2 }
  for i in 1..<actual_steps {
    let alpha = i.to_double() / actual_steps.to_double()
    let t = smoothstep(alpha)
    let timestamp = first.duration + blend_duration * alpha
    let positions : Array[(String, Double)] = []
    for j in 0..<first_end.positions.length() {
      let (name, pos1) = first_end.positions[j]
      // 在 second_start 中查找同名关节
      let mut pos2 = pos1
      for k in 0..<second_start.positions.length() {
        let (sname, spos) = second_start.positions[k]
        if sname == name {
          pos2 = spos
          break
        }
      }
      positions.push((name, pos1 + (pos2 - pos1) * t))
    }
    result.push({ positions, timestamp })
  }
  // 3. 添加 second 轨迹的所有点（时间偏移）
  let time_offset = first.duration + blend_duration
  for wp in second.waypoints {
    let positions = wp.positions
    result.push({ positions, timestamp: wp.timestamp + time_offset })
  }
  { waypoints: result, duration: time_offset + second.duration }
}
