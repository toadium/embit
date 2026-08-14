///|
/// 机器人模型工厂：预定义常见机型的 URDF 模型描述。
///
/// 提供人形、四足、机械臂等标准机型的 `RobotModel` 构建方法，
/// 避免每个项目重复手写关节规格与安全限幅。
/// 真实项目可在此基础上通过 URDF 解析器覆盖。
pub struct RobotBuilder {
  _sealed : Unit
}

///|
/// 构建 12-DOF 人形机器人模型（双腿 6 + 双臂 6）。
///
/// 关节：left/right_hip_yaw, hip_roll, hip_pitch, knee, ankle_pitch, ankle_roll
/// 传感器：头部相机 + 躯干 IMU
/// 安全限幅：2.0 rad/s, 50 Nm, 0.05m
pub fn RobotBuilder::humanoid_12dof() -> RobotModel {
  let _builder = RobotBuilder::{ _sealed: () }
  let joints : Array[JointSpec] = [
    // 左腿
    {
      name: "left_hip_yaw",
      joint_type: Revolute,
      min_position: -1.57,
      max_position: 1.57,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "left_hip_roll",
      joint_type: Revolute,
      min_position: -0.78,
      max_position: 0.78,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "left_hip_pitch",
      joint_type: Revolute,
      min_position: -1.57,
      max_position: 1.57,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "left_knee",
      joint_type: Revolute,
      min_position: -0.01,
      max_position: 2.35,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "left_ankle_pitch",
      joint_type: Revolute,
      min_position: -0.78,
      max_position: 0.78,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "left_ankle_roll",
      joint_type: Revolute,
      min_position: -0.39,
      max_position: 0.39,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    // 右腿
    {
      name: "right_hip_yaw",
      joint_type: Revolute,
      min_position: -1.57,
      max_position: 1.57,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "right_hip_roll",
      joint_type: Revolute,
      min_position: -0.78,
      max_position: 0.78,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "right_hip_pitch",
      joint_type: Revolute,
      min_position: -1.57,
      max_position: 1.57,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "right_knee",
      joint_type: Revolute,
      min_position: -0.01,
      max_position: 2.35,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "right_ankle_pitch",
      joint_type: Revolute,
      min_position: -0.78,
      max_position: 0.78,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
    {
      name: "right_ankle_roll",
      joint_type: Revolute,
      min_position: -0.39,
      max_position: 0.39,
      max_velocity: 2.0,
      max_effort: 50.0,
    },
  ]
  let sensors : Array[SensorSpec] = [
    { name: "head_camera", sensor_type: Camera, topic: "/camera/image" },
    { name: "imu", sensor_type: Imu, topic: "/imu/data" },
  ]
  {
    urdf_path: "models/humanoid_12dof.urdf",
    joints,
    sensors,
    limits: {
      max_joint_velocity: 2.0,
      max_joint_effort: 50.0,
      collision_check_distance: 0.05,
    },
  }
}

///|
/// 构建 12-DOF 四足机器人模型（四腿各 3 关节：hip, thigh, knee）。
///
/// 传感器：LiDAR + IMU
/// 安全限幅：3.0 rad/s, 30 Nm, 0.1m
pub fn RobotBuilder::quadruped_12dof() -> RobotModel {
  let leg_names = ["fl", "fr", "rl", "rr"]
  let joints : Array[JointSpec] = []
  for leg in leg_names {
    joints.push({
      name: "\{leg}_hip",
      joint_type: Revolute,
      min_position: -0.78,
      max_position: 0.78,
      max_velocity: 3.0,
      max_effort: 30.0,
    })
    joints.push({
      name: "\{leg}_thigh",
      joint_type: Revolute,
      min_position: -1.57,
      max_position: 1.57,
      max_velocity: 3.0,
      max_effort: 30.0,
    })
    joints.push({
      name: "\{leg}_knee",
      joint_type: Revolute,
      min_position: -0.01,
      max_position: 2.35,
      max_velocity: 3.0,
      max_effort: 30.0,
    })
  }
  let sensors : Array[SensorSpec] = [
    { name: "lidar", sensor_type: Lidar, topic: "/lidar/scan" },
    { name: "imu", sensor_type: Imu, topic: "/imu/data" },
  ]
  {
    urdf_path: "models/quadruped_12dof.urdf",
    joints,
    sensors,
    limits: {
      max_joint_velocity: 3.0,
      max_joint_effort: 30.0,
      collision_check_distance: 0.1,
    },
  }
}

///|
/// 构建 6-DOF 工业机械臂模型。
///
/// 关节：joint1~joint6（均为 Revolute）
/// 传感器：腕部相机
/// 安全限幅：1.5 rad/s, 20 Nm, 0.02m
pub fn RobotBuilder::arm_6dof() -> RobotModel {
  let joints : Array[JointSpec] = []
  for i in 1..<=6 {
    joints.push({
      name: "joint\{i}",
      joint_type: Revolute,
      min_position: -3.14,
      max_position: 3.14,
      max_velocity: 1.5,
      max_effort: 20.0,
    })
  }
  let sensors : Array[SensorSpec] = [
    { name: "wrist_camera", sensor_type: Camera, topic: "/wrist_camera/image" },
  ]
  {
    urdf_path: "models/arm_6dof.urdf",
    joints,
    sensors,
    limits: {
      max_joint_velocity: 1.5,
      max_joint_effort: 20.0,
      collision_check_distance: 0.02,
    },
  }
}

///|
/// 构建 14-DOF 双臂机器人模型（左右各 7-DOF）。
///
/// 传感器：头部相机 + 左/右腕相机 + IMU
/// 安全限幅：1.8 rad/s, 25 Nm, 0.03m
pub fn RobotBuilder::dual_arm_14dof() -> RobotModel {
  let arm_names = ["left", "right"]
  let joints : Array[JointSpec] = []
  for arm in arm_names {
    for i in 1..<=7 {
      joints.push({
        name: "\{arm}_arm_joint\{i}",
        joint_type: Revolute,
        min_position: -3.14,
        max_position: 3.14,
        max_velocity: 1.8,
        max_effort: 25.0,
      })
    }
  }
  let sensors : Array[SensorSpec] = [
    { name: "head_camera", sensor_type: Camera, topic: "/head_camera/image" },
    {
      name: "left_wrist_camera",
      sensor_type: Camera,
      topic: "/left_wrist_camera/image",
    },
    {
      name: "right_wrist_camera",
      sensor_type: Camera,
      topic: "/right_wrist_camera/image",
    },
    { name: "imu", sensor_type: Imu, topic: "/imu/data" },
  ]
  {
    urdf_path: "models/dual_arm_14dof.urdf",
    joints,
    sensors,
    limits: {
      max_joint_velocity: 1.8,
      max_joint_effort: 25.0,
      collision_check_distance: 0.03,
    },
  }
}

///|
/// 构建 2-DOF 移动底盘模型（线速度 + 角速度）。
///
/// 传感器：LiDAR + IMU
/// 安全限幅：1.0 m/s, 10 Nm, 0.1m
pub fn RobotBuilder::mobile_base() -> RobotModel {
  let joints : Array[JointSpec] = [
    {
      name: "linear_x",
      joint_type: Prismatic,
      min_position: -10.0,
      max_position: 10.0,
      max_velocity: 1.0,
      max_effort: 10.0,
    },
    {
      name: "angular_z",
      joint_type: Continuous,
      min_position: -3.14,
      max_position: 3.14,
      max_velocity: 1.0,
      max_effort: 10.0,
    },
  ]
  let sensors : Array[SensorSpec] = [
    { name: "lidar", sensor_type: Lidar, topic: "/lidar/scan" },
    { name: "imu", sensor_type: Imu, topic: "/imu/data" },
  ]
  {
    urdf_path: "models/mobile_base.urdf",
    joints,
    sensors,
    limits: {
      max_joint_velocity: 1.0,
      max_joint_effort: 10.0,
      collision_check_distance: 0.1,
    },
  }
}

///|
/// 从 RobotModel 创建 RobotModelInfo。
///
/// `name` 为机型名称，`version` 为版本号。
pub fn RobotModel::to_info(
  self : RobotModel,
  name : String,
  version : String,
) -> RobotModelInfo {
  { name, version, dof: self.joints.length(), urdf_path: self.urdf_path }
}
