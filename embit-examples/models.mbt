///|
/// Embit 示例工程集：机器人模型构建工具。
///
/// 提供 humanoid / quadruped / arm 三种机型的 RobotModel 构建函数，
/// 以及可视化面板创建辅助函数。

///|
/// 构建人形机器人模型（12 自由度，双腿 + 双臂 + 躯干）。
fn humanoid_model() -> @core.RobotModel {
  {
    urdf_path: "models/humanoid.urdf",
    joints: [],
    sensors: [
      { name: "camera", sensor_type: Camera, topic: "/camera/image" },
      { name: "imu", sensor_type: Imu, topic: "/imu/data" },
    ],
    limits: {
      max_joint_velocity: 2.0,
      max_joint_effort: 50.0,
      collision_check_distance: 0.05,
    },
  }
}

///|
/// 构建四足机器人模型（12 自由度，四腿各 3 关节）。
fn quadruped_model() -> @core.RobotModel {
  {
    urdf_path: "models/quadruped.urdf",
    joints: [],
    sensors: [{ name: "lidar", sensor_type: Lidar, topic: "/lidar/scan" }],
    limits: {
      max_joint_velocity: 3.0,
      max_joint_effort: 30.0,
      collision_check_distance: 0.1,
    },
  }
}

///|
/// 构建机械臂模型（6 自由度）。
fn arm_model() -> @core.RobotModel {
  {
    urdf_path: "models/arm6dof.urdf",
    joints: [],
    sensors: [
      {
        name: "wrist_camera",
        sensor_type: Camera,
        topic: "/wrist_camera/image",
      },
    ],
    limits: {
      max_joint_velocity: 1.5,
      max_joint_effort: 20.0,
      collision_check_distance: 0.02,
    },
  }
}

///|
/// 创建可视化面板并添加标准组件。
fn make_view_panel(model_info : @core.RobotModelInfo) -> @view.ViewPanel {
  let panel = @view.ViewPanel::with_model(model_info)
  panel.add_widget({
    widget_type: JointPlot,
    title: "Joint Trajectories",
    topic: "/joint_states",
  })
  panel.add_widget({
    widget_type: View3D,
    title: "3D Robot View",
    topic: "/robot_state",
  })
  panel.add_widget({
    widget_type: LogPanel,
    title: "Control Log",
    topic: "/control/log",
  })
  panel
}
