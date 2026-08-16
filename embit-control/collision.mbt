///|
/// 碰撞检测器：自碰撞 + 环境碰撞检测。
///
/// Phase 5.3 新增：为安全认证提供碰撞检测模块。
/// `CollisionDetector` 封装安全距离参数，
/// 检测机器人自碰撞（关节间距离）与环境碰撞（关节与障碍物距离）。
/// 占位模式仅验证参数有效性；真实模式需接入碰撞检测库（如 FCL/Bullet）。

///|
/// 碰撞检测结果。
pub(all) struct CollisionResult {
  self_collision : Bool // 是否发生自碰撞
  environment_collision : Bool // 是否发生环境碰撞
  min_distance : Double // 最小安全距离
  collision_pairs : Array[(String, String)] // 碰撞对（关节名）
}

///|
/// 碰撞检测器。
pub struct CollisionDetector {
  safety_distance : Double // 安全距离（m）
  mut joint_positions : Array[(String, Double)] // 关节位置缓存
  mut obstacle_positions : Array[(Double, Double, Double)] // 障碍物位置缓存
}

///|
/// 创建碰撞检测器。
///
/// `safety_distance` 为最小安全距离（米）。
pub fn CollisionDetector::new(safety_distance : Double) -> CollisionDetector {
  { safety_distance, joint_positions: [], obstacle_positions: [] }
}

///|
/// 更新关节位置缓存。
pub fn CollisionDetector::update_joints(
  self : CollisionDetector,
  positions : Array[(String, Double)],
) -> Unit {
  self.joint_positions = positions
}

///|
/// 添加障碍物。
pub fn CollisionDetector::add_obstacle(
  self : CollisionDetector,
  x : Double,
  y : Double,
  z : Double,
) -> Unit {
  self.obstacle_positions.push((x, y, z))
}

///|
/// 清除所有障碍物。
pub fn CollisionDetector::clear_obstacles(self : CollisionDetector) -> Unit {
  self.obstacle_positions = []
}

///|
/// 检查自碰撞。
///
/// 占位实现：当关节数 > 0 且安全距离为正值时返回无碰撞。
/// 真实实现需计算关节间几何距离。
pub fn CollisionDetector::check_self_collision(
  self : CollisionDetector,
) -> CollisionResult {
  let has_collision = self.safety_distance < 0.0
  {
    self_collision: has_collision,
    environment_collision: false,
    min_distance: self.safety_distance,
    collision_pairs: [],
  }
}

///|
/// 检查环境碰撞。
///
/// 占位实现：当障碍物数 > 0 且安全距离为正值时返回无碰撞。
/// 真实实现需计算机器人连杆与障碍物间距离。
pub fn CollisionDetector::check_environment_collision(
  self : CollisionDetector,
) -> CollisionResult {
  let has_collision = self.safety_distance < 0.0 &&
    self.obstacle_positions.length() > 0
  {
    self_collision: false,
    environment_collision: has_collision,
    min_distance: self.safety_distance,
    collision_pairs: [],
  }
}

///|
/// 综合碰撞检测：自碰撞 + 环境碰撞。
pub fn CollisionDetector::check_all(
  self : CollisionDetector,
) -> CollisionResult {
  let self_result = self.check_self_collision()
  let env_result = self.check_environment_collision()
  {
    self_collision: self_result.self_collision,
    environment_collision: env_result.environment_collision,
    min_distance: self.safety_distance,
    collision_pairs: [],
  }
}

///|
/// 查询安全距离。
pub fn CollisionDetector::safety_distance(self : CollisionDetector) -> Double {
  self.safety_distance
}

///|
/// 查询障碍物数量。
pub fn CollisionDetector::obstacle_count(self : CollisionDetector) -> Int {
  self.obstacle_positions.length()
}
