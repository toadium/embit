///|
/// 关节类型（URDF 标准分类）。
pub(all) enum JointType {
  Revolute // 旋转关节（有角度限制）
  Prismatic // 移动关节（有行程限制）
  Continuous // 连续旋转关节（无角度限制）
  Fixed // 固定关节（零自由度）
} derive(Eq, Debug)

///|
/// 关节规格描述。
///
/// 来源于 URDF 模型解析，定义关节的运动学约束与安全限幅。
pub(all) struct JointSpec {
  name : String
  joint_type : JointType
  min_position : Double // 最小角度（rad）
  max_position : Double // 最大角度（rad）
  max_velocity : Double // 最大角速度（rad/s）
  max_effort : Double // 最大力矩（Nm）
} derive(Eq, Debug)

///|
/// 传感器规格描述。
pub(all) struct SensorSpec {
  name : String
  sensor_type : SensorType
  topic : String // 话题名（Ignition Transport 话题）
} derive(Eq, Debug)

///|
/// 安全约束参数。
///
/// embit-control 安全联锁模块据此检查关节速度/力矩是否越限，
/// 以及碰撞检测的最小安全距离。
pub(all) struct SafetyLimits {
  max_joint_velocity : Double // 最大关节速度（rad/s）
  max_joint_effort : Double // 最大关节力矩（Nm）
  collision_check_distance : Double // 碰撞检查距离（m）
} derive(Eq, Debug)

///|
/// 机器人模型描述。
///
/// 由 URDF 文件解析生成，是 embit-control 运动控制框架的输入。
pub(all) struct RobotModel {
  urdf_path : String
  joints : Array[JointSpec]
  sensors : Array[SensorSpec]
  limits : SafetyLimits
} derive(Eq, Debug)

///|
/// 机器人模型运行时信息。
///
/// 由 `Robot::get_model_info` 返回，提供机型名称、版本与自由度等元数据。
pub(all) struct RobotModelInfo {
  name : String
  version : String
  dof : Int // 自由度
  urdf_path : String
} derive(Eq, Debug)
