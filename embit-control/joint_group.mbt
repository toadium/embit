///|
/// 关节组：将机器人关节按功能分组管理。
///
/// 例如人形机器人的左腿、右腿、左臂、右臂可各为一关节组，
/// 便于分组规划轨迹与施加控制。
pub struct JointGroup {
  name : String
  joint_names : Array[String]
  positions : Map[String, Double]
}

///|
/// 创建关节组。
///
/// `name` 为组名，`joint_names` 为组内关节名列表。
pub fn JointGroup::new(
  name : String,
  joint_names : Array[String],
) -> JointGroup {
  let positions : Map[String, Double] = Map([])
  for jn in joint_names {
    positions[jn] = 0.0
  }
  { name, joint_names, positions }
}

///|
/// 组名。
pub fn JointGroup::get_name(self : JointGroup) -> String {
  self.name
}

///|
/// 组内关节数。
pub fn JointGroup::size(self : JointGroup) -> Int {
  self.joint_names.length()
}

///|
/// 设置关节位置。
///
/// 若关节名不在组内，抛出 `RobotError::InvalidConfig`。
pub fn JointGroup::set_position(
  self : JointGroup,
  joint_name : String,
  value : Double,
) -> Unit raise @core.RobotError {
  if self.positions.contains(joint_name) {
    self.positions[joint_name] = value
  } else {
    raise InvalidConfig("joint \{joint_name} not in group \{self.name}")
  }
}

///|
/// 获取关节位置。
///
/// 若关节名不在组内，抛出 `RobotError::InvalidConfig`。
pub fn JointGroup::get_position(
  self : JointGroup,
  joint_name : String,
) -> Double raise @core.RobotError {
  match self.positions.get(joint_name) {
    Some(v) => v
    None => raise InvalidConfig("joint \{joint_name} not in group \{self.name}")
  }
}

///|
/// 批量设置关节位置。
///
/// `values` 为 (关节名, 位置) 数组，长度应与组大小一致。
pub fn JointGroup::set_positions(
  self : JointGroup,
  values : Array[(String, Double)],
) -> Unit raise @core.RobotError {
  for i in 0..<values.length() {
    let (name, value) = values[i]
    self.set_position(name, value)
  }
}

///|
/// 获取所有关节位置（按 joint_names 顺序）。
pub fn JointGroup::get_positions(self : JointGroup) -> Array[(String, Double)] {
  let result : Array[(String, Double)] = []
  for jn in self.joint_names {
    let v = self.positions.get_or_default(jn, 0.0)
    result.push((jn, v))
  }
  result
}

///|
/// 重置所有关节位置为零。
pub fn JointGroup::reset(self : JointGroup) -> Unit {
  for jn in self.joint_names {
    self.positions[jn] = 0.0
  }
}

///|
/// 查询关节是否在组内。
pub fn JointGroup::contains(self : JointGroup, joint_name : String) -> Bool {
  self.positions.contains(joint_name)
}

///|
/// 关节组管理器：管理多个关节组。
pub struct JointGroupManager {
  groups : Map[String, JointGroup]
}

///|
/// 创建关节组管理器。
pub fn JointGroupManager::new() -> JointGroupManager {
  { groups: Map([]) }
}

///|
/// 添加关节组。
pub fn JointGroupManager::add(
  self : JointGroupManager,
  group : JointGroup,
) -> Unit {
  self.groups[group.get_name()] = group
}

///|
/// 获取关节组。
///
/// 若组名不存在，抛出 `RobotError::InvalidConfig`。
pub fn JointGroupManager::get(
  self : JointGroupManager,
  name : String,
) -> JointGroup raise @core.RobotError {
  match self.groups.get(name) {
    Some(g) => g
    None => raise InvalidConfig("group \{name} not found")
  }
}

///|
/// 查询关节组是否存在。
pub fn JointGroupManager::contains(
  self : JointGroupManager,
  name : String,
) -> Bool {
  self.groups.contains(name)
}

///|
/// 获取所有组名。
pub fn JointGroupManager::group_names(
  self : JointGroupManager,
) -> Array[String] {
  let names : Array[String] = []
  self.groups.each(fn(name, _) { names.push(name) })
  names
}

///|
/// 组数。
pub fn JointGroupManager::size(self : JointGroupManager) -> Int {
  self.groups.length()
}
