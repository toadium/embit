///|
/// 仿真环境客户端，封装 Ignition Transport 话题通信。
///
/// 通过 FFI 绑定 Ignition Transport C API，提供话题发布/订阅与服务调用。
/// 条件编译：EMBIT_HAS_IGNITION 启用真实 API，否则占位回退（仅记录计数）。
/// MoonBit 侧跟踪最近发布的消息与服务调用，用于集成测试验证。
///
/// # Example
/// ```mbt check
/// test {
///   let client = @embit-gazebo.GazeboClient::connect("localhost:9000")
///   inspect(client.is_connected(), content="true")
/// }
/// ```
pub struct GazeboClient {
  node : IgnitionNode
  mut last_publish_topic : String // 最近发布的话题名
  mut last_service : String // 最近调用的服务名
}

///|
/// 连接仿真环境。
///
/// `address` 格式为 `host:port`，如 `"localhost:9000"`。
/// 占位模式始终连接成功；真实模式（EMBIT_HAS_IGNITION）连接失败时返回未连接节点。
pub fn GazeboClient::connect(address : String) -> GazeboClient {
  let node = embit_gazebo_connect(@utf8.encode(address))
  { node, last_publish_topic: "", last_service: "" }
}

///|
/// 发布消息到指定话题。
///
/// `topic` 为话题名，`data` 为原始消息字节流。
/// 失败时抛出 `RobotError::ActionExecuteError`。
pub fn GazeboClient::publish(
  self : GazeboClient,
  topic : String,
  data : Bytes,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_publish(self.node, @utf8.encode(topic), data)
  if status < 0 {
    raise ActionExecuteError("gazebo publish failed: node not connected")
  }
  self.last_publish_topic = topic
}

///|
/// 查询最近发布的话题名。
pub fn GazeboClient::last_publish_topic(self : GazeboClient) -> String {
  self.last_publish_topic
}

///|
/// 查询节点连接状态。
pub fn GazeboClient::is_connected(self : GazeboClient) -> Bool {
  embit_gazebo_is_connected(self.node) != 0
}

///|
/// 获取已操作话题计数（用于测试验证 FFI 通道）。
pub fn GazeboClient::topic_count(self : GazeboClient) -> Int {
  embit_gazebo_topic_count(self.node)
}

///|
/// 断开与仿真环境的连接。
pub fn GazeboClient::disconnect(self : GazeboClient) -> Unit {
  embit_gazebo_disconnect(self.node)
}

///|
/// 订阅话题。
///
/// `topic` 为话题名。失败时抛出 `RobotError::ConnectError`。
pub fn GazeboClient::subscribe(
  self : GazeboClient,
  topic : String,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_subscribe(self.node, @utf8.encode(topic))
  if status < 0 {
    raise ConnectError("gazebo subscribe failed: node not connected")
  }
}

///|
/// 取消订阅。
///
/// 失败时抛出 `RobotError::ConnectError`。
pub fn GazeboClient::unsubscribe(
  self : GazeboClient,
  topic : String,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_unsubscribe(self.node, @utf8.encode(topic))
  if status < 0 {
    raise ConnectError(
      "gazebo unsubscribe failed: not connected or no subscription",
    )
  }
}

///|
/// 获取已订阅话题计数。
pub fn GazeboClient::subscription_count(self : GazeboClient) -> Int {
  embit_gazebo_subscription_count(self.node)
}

///|
/// 调用仿真服务（同步 RPC）。
///
/// `service` 为服务名，`request` 为请求消息字节流。
/// 失败时抛出 `RobotError::ActionExecuteError`。
pub fn GazeboClient::service_call(
  self : GazeboClient,
  service : String,
  request : Bytes,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_service_call(
    self.node,
    @utf8.encode(service),
    request,
  )
  if status < 0 {
    raise ActionExecuteError("gazebo service_call failed: node not connected")
  }
  self.last_service = service
}

///|
/// 查询最近调用的服务名。
pub fn GazeboClient::last_service(self : GazeboClient) -> String {
  self.last_service
}

///|
/// 获取服务调用计数（用于测试验证）。
pub fn GazeboClient::service_call_count(self : GazeboClient) -> Int {
  embit_gazebo_service_call_count(self.node)
}

// ===== 仿真世界控制 =====

///|
/// 重置仿真世界到初始状态。
///
/// 清除所有物体位姿、速度，恢复到仿真启动时的初始配置。
/// 失败时抛出 `RobotError::ActionExecuteError`。
pub fn GazeboClient::reset_world(
  self : GazeboClient,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_reset_world(self.node)
  if status < 0 {
    raise ActionExecuteError("gazebo reset_world failed: node not connected")
  }
}

///|
/// 暂停物理仿真。
///
/// 暂停后可步进执行（`step`），用于调试与精确控制。
pub fn GazeboClient::pause(self : GazeboClient) -> Unit raise @core.RobotError {
  let status = embit_gazebo_pause(self.node)
  if status < 0 {
    raise ActionExecuteError("gazebo pause failed: node not connected")
  }
}

///|
/// 恢复物理仿真。
pub fn GazeboClient::unpause(
  self : GazeboClient,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_unpause(self.node)
  if status < 0 {
    raise ActionExecuteError("gazebo unpause failed: node not connected")
  }
}

///|
/// 查询仿真是否已暂停。
pub fn GazeboClient::is_paused(self : GazeboClient) -> Bool {
  embit_gazebo_is_paused(self.node) != 0
}

///|
/// 步进仿真 `steps` 步。
///
/// 仿真必须已暂停（`pause`），否则步进无效。
/// `steps` 必须大于 0。
pub fn GazeboClient::step(
  self : GazeboClient,
  steps : Int,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_step(self.node, steps)
  if status < 0 {
    raise ActionExecuteError(
      "gazebo step failed: node not connected or steps <= 0",
    )
  }
}

///|
/// 设置重力向量。
///
/// `gx` / `gy` / `gz` 为重力加速度分量（m/s²）。
/// 默认重力为 (0, 0, -9.81)。
pub fn GazeboClient::set_gravity(
  self : GazeboClient,
  gx : Double,
  gy : Double,
  gz : Double,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_set_gravity(self.node, gx, gy, gz)
  if status < 0 {
    raise ActionExecuteError("gazebo set_gravity failed: node not connected")
  }
}

///|
/// 查询当前重力 Z 分量（用于测试验证）。
pub fn GazeboClient::get_gravity_z(self : GazeboClient) -> Double {
  embit_gazebo_get_gravity_z(self.node)
}

///|
/// 获取世界控制操作计数（用于测试验证）。
pub fn GazeboClient::world_control_count(self : GazeboClient) -> Int {
  embit_gazebo_world_control_count(self.node)
}

// ===== 场景管理 =====

///|
/// 生成模型（spawn）。
///
/// `model_name` 为模型名称（如 SDF/URDF 文件名或模型库中的名称）。
/// 失败时抛出 `RobotError::ActionExecuteError`。
pub fn GazeboClient::spawn_model(
  self : GazeboClient,
  model_name : String,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_spawn_model(self.node, @utf8.encode(model_name))
  if status < 0 {
    raise ActionExecuteError("gazebo spawn_model failed: node not connected")
  }
}

///|
/// 删除模型（remove）。
///
/// `model_name` 为要删除的模型名称。
/// 失败时抛出 `RobotError::ActionExecuteError`。
pub fn GazeboClient::remove_model(
  self : GazeboClient,
  model_name : String,
) -> Unit raise @core.RobotError {
  let status = embit_gazebo_remove_model(self.node, @utf8.encode(model_name))
  if status < 0 {
    raise ActionExecuteError(
      "gazebo remove_model failed: node not connected or no models",
    )
  }
}

///|
/// 获取场景中模型数量。
pub fn GazeboClient::model_count(self : GazeboClient) -> Int {
  embit_gazebo_model_count(self.node)
}
