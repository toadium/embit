///|
/// Ignition Transport 节点句柄。
///
/// 不透明类型，由 C 侧 `embit_gazebo_connect` 创建，
/// 封装为 GC 管理的外部对象（external object）。
/// Phase 1 后续将绑定真实 `ign_transport_node_t`。
type IgnitionNode

///|
/// 创建并连接 Ignition Transport 通信节点。
///
/// `address` 为 UTF-8 编码的连接地址（如 `b"localhost:9000"`）。
#borrow(address)
extern "c" fn embit_gazebo_connect(address : Bytes) -> IgnitionNode = "embit_gazebo_connect"

///|
#borrow(node, topic, data)
extern "c" fn embit_gazebo_publish(
  node : IgnitionNode,
  topic : Bytes,
  data : Bytes,
) -> Int = "embit_gazebo_publish"

///|
#borrow(node)
extern "c" fn embit_gazebo_is_connected(node : IgnitionNode) -> Int = "embit_gazebo_is_connected"

///|
#borrow(node)
extern "c" fn embit_gazebo_topic_count(node : IgnitionNode) -> Int = "embit_gazebo_topic_count"

///|
#borrow(node)
extern "c" fn embit_gazebo_disconnect(node : IgnitionNode) -> Unit = "embit_gazebo_disconnect"

///|
/// 订阅话题。
#borrow(node, topic)
extern "c" fn embit_gazebo_subscribe(node : IgnitionNode, topic : Bytes) -> Int = "embit_gazebo_subscribe"

///|
/// 取消订阅。
#borrow(node, topic)
extern "c" fn embit_gazebo_unsubscribe(
  node : IgnitionNode,
  topic : Bytes,
) -> Int = "embit_gazebo_unsubscribe"

///|
/// 获取已订阅话题计数。
#borrow(node)
extern "c" fn embit_gazebo_subscription_count(node : IgnitionNode) -> Int = "embit_gazebo_subscription_count"

///|
/// 调用仿真服务。
#borrow(node, service, request)
extern "c" fn embit_gazebo_service_call(
  node : IgnitionNode,
  service : Bytes,
  request : Bytes,
) -> Int = "embit_gazebo_service_call"

///|
/// 获取服务调用计数。
#borrow(node)
extern "c" fn embit_gazebo_service_call_count(node : IgnitionNode) -> Int = "embit_gazebo_service_call_count"

// ===== 仿真世界控制 =====

///|
/// 重置仿真世界到初始状态。
#borrow(node)
extern "c" fn embit_gazebo_reset_world(node : IgnitionNode) -> Int = "embit_gazebo_reset_world"

///|
/// 暂停物理仿真。
#borrow(node)
extern "c" fn embit_gazebo_pause(node : IgnitionNode) -> Int = "embit_gazebo_pause"

///|
/// 恢复物理仿真。
#borrow(node)
extern "c" fn embit_gazebo_unpause(node : IgnitionNode) -> Int = "embit_gazebo_unpause"

///|
/// 查询暂停状态。
#borrow(node)
extern "c" fn embit_gazebo_is_paused(node : IgnitionNode) -> Int = "embit_gazebo_is_paused"

///|
/// 步进仿真。
#borrow(node)
extern "c" fn embit_gazebo_step(node : IgnitionNode, steps : Int) -> Int = "embit_gazebo_step"

///|
/// 设置重力向量。
#borrow(node)
extern "c" fn embit_gazebo_set_gravity(
  node : IgnitionNode,
  gx : Double,
  gy : Double,
  gz : Double,
) -> Int = "embit_gazebo_set_gravity"

///|
/// 查询重力 Z 分量。
#borrow(node)
extern "c" fn embit_gazebo_get_gravity_z(node : IgnitionNode) -> Double = "embit_gazebo_get_gravity_z"

///|
/// 获取世界控制操作计数。
#borrow(node)
extern "c" fn embit_gazebo_world_control_count(node : IgnitionNode) -> Int = "embit_gazebo_world_control_count"

// ===== 场景管理 =====

///|
/// 生成模型（spawn）。
#borrow(node, model_name)
extern "c" fn embit_gazebo_spawn_model(
  node : IgnitionNode,
  model_name : Bytes,
) -> Int = "embit_gazebo_spawn_model"

///|
/// 删除模型（remove）。
#borrow(node, model_name)
extern "c" fn embit_gazebo_remove_model(
  node : IgnitionNode,
  model_name : Bytes,
) -> Int = "embit_gazebo_remove_model"

///|
/// 获取场景中模型数量。
#borrow(node)
extern "c" fn embit_gazebo_model_count(node : IgnitionNode) -> Int = "embit_gazebo_model_count"
