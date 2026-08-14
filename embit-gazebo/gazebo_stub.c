// gazebo_stub.c — Embit Gazebo FFI 桥接（功能化占位实现）
//
// 当前为自包含占位实现，不依赖 Ignition Transport C 库。
// 消息内容跟踪由 MoonBit 侧 GazeboClient 维护，C 侧仅记录操作计数与状态。
// 后续将替换为真实 Ignition Transport API 调用：
//   - ign_transport_node_create / ign_transport_node_destroy
//   - ign_transport_publish / ign_transport_subscribe
//
// 编译：由 MoonBit native-stub 机制自动编译并链接。

#include <moonbit.h>
#include <stdint.h>

// 占位的 Ignition Transport 通信节点
typedef struct {
  int32_t connected;             // 连接状态（1=已连接, 0=已断开）
  int32_t topic_count;           // 已发布话题计数（占位统计）
  int32_t subscription_count;    // 已订阅话题计数（占位统计）
  int32_t service_call_count;    // 服务调用计数（占位统计）
  int32_t paused;                // 仿真暂停状态（1=暂停, 0=运行）
  int32_t world_control_count;   // 世界控制操作计数（占位统计）
  int32_t model_count;           // 场景中模型数量（占位统计）
  double  gravity_x;             // 重力 X 分量
  double  gravity_y;             // 重力 Y 分量
  double  gravity_z;             // 重力 Z 分量
} embit_gazebo_node_t;

// no-op finalizer：节点结构体无堆分配资源，无需释放。
// 必须提供非 NULL finalizer 以避免 GC 行为异常。
static void embit_gazebo_node_finalize(void *ptr) {
  (void)ptr;
}

// 创建并连接通信节点
// address: UTF-8 编码的连接地址（如 "localhost:9000"），占位实现中未使用
// 返回：GC 管理的外部对象，封装 embit_gazebo_node_t
MOONBIT_FFI_EXPORT
embit_gazebo_node_t *embit_gazebo_connect(moonbit_bytes_t address) {
  (void)address; // 占位：地址参数暂未使用
  embit_gazebo_node_t *node = (embit_gazebo_node_t *)moonbit_make_external_object(
    embit_gazebo_node_finalize,
    sizeof(embit_gazebo_node_t)
  );
  node->connected = 1;
  node->topic_count = 0;
  node->subscription_count = 0;
  node->service_call_count = 0;
  node->paused = 0;
  node->world_control_count = 0;
  node->model_count = 0;
  node->gravity_x = 0.0;
  node->gravity_y = 0.0;
  node->gravity_z = -9.81;
  return node;
}

// 发布消息到指定话题
// node: 通信节点句柄
// topic: UTF-8 编码的话题名
// data: 原始消息字节流
// 返回：0=成功, -1=失败（未连接或空指针）
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_publish(
  embit_gazebo_node_t *node,
  moonbit_bytes_t topic,
  moonbit_bytes_t data
) {
  (void)topic; // 占位：话题名暂未使用
  (void)data;  // 占位：消息数据暂未使用
  if (node == NULL || !node->connected) {
    return -1;
  }
  node->topic_count++;
  return 0;
}

// 查询节点连接状态
// 返回：1=已连接, 0=未连接
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_is_connected(embit_gazebo_node_t *node) {
  if (node == NULL) {
    return 0;
  }
  return node->connected;
}

// 获取已操作话题计数（占位统计，用于测试验证）
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_topic_count(embit_gazebo_node_t *node) {
  if (node == NULL) {
    return 0;
  }
  return node->topic_count;
}

// 断开连接
MOONBIT_FFI_EXPORT
void embit_gazebo_disconnect(embit_gazebo_node_t *node) {
  if (node != NULL) {
    node->connected = 0;
  }
}

// 订阅话题
// node: 通信节点句柄
// topic: UTF-8 编码的话题名
// 返回：0=成功, -1=失败（未连接或空指针）
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_subscribe(
  embit_gazebo_node_t *node,
  moonbit_bytes_t topic
) {
  (void)topic; // 占位：话题名暂未使用
  if (node == NULL || !node->connected) {
    return -1;
  }
  node->subscription_count++;
  return 0;
}

// 取消订阅
// 返回：0=成功, -1=失败（未连接或空指针或无订阅）
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_unsubscribe(
  embit_gazebo_node_t *node,
  moonbit_bytes_t topic
) {
  (void)topic;
  if (node == NULL || !node->connected || node->subscription_count <= 0) {
    return -1;
  }
  node->subscription_count--;
  return 0;
}

// 获取已订阅话题计数
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_subscription_count(embit_gazebo_node_t *node) {
  if (node == NULL) {
    return 0;
  }
  return node->subscription_count;
}

// 调用仿真服务
// node: 通信节点句柄
// service: UTF-8 编码的服务名
// request: 请求消息字节流
// 返回：0=成功, -1=失败（未连接或空指针）
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_service_call(
  embit_gazebo_node_t *node,
  moonbit_bytes_t service,
  moonbit_bytes_t request
) {
  (void)service;
  (void)request;
  if (node == NULL || !node->connected) {
    return -1;
  }
  node->service_call_count++;
  return 0;
}

// 获取服务调用计数
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_service_call_count(embit_gazebo_node_t *node) {
  if (node == NULL) {
    return 0;
  }
  return node->service_call_count;
}

// ===== 仿真世界控制 =====

// 重置仿真世界到初始状态
// 返回：0=成功, -1=失败（未连接或空指针）
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_reset_world(embit_gazebo_node_t *node) {
  if (node == NULL || !node->connected) {
    return -1;
  }
  node->world_control_count++;
  node->paused = 0;
  return 0;
}

// 暂停物理仿真
// 返回：0=成功, -1=失败
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_pause(embit_gazebo_node_t *node) {
  if (node == NULL || !node->connected) {
    return -1;
  }
  node->paused = 1;
  node->world_control_count++;
  return 0;
}

// 恢复物理仿真
// 返回：0=成功, -1=失败
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_unpause(embit_gazebo_node_t *node) {
  if (node == NULL || !node->connected) {
    return -1;
  }
  node->paused = 0;
  node->world_control_count++;
  return 0;
}

// 查询暂停状态
// 返回：1=暂停, 0=运行, -1=失败
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_is_paused(embit_gazebo_node_t *node) {
  if (node == NULL) {
    return -1;
  }
  return node->paused;
}

// 步进仿真 N 步
// steps: 步进数（必须 > 0）
// 返回：0=成功, -1=失败
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_step(embit_gazebo_node_t *node, int32_t steps) {
  if (node == NULL || !node->connected || steps <= 0) {
    return -1;
  }
  node->world_control_count++;
  return 0;
}

// 设置重力向量
// gx, gy, gz: 重力分量（m/s²）
// 返回：0=成功, -1=失败
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_set_gravity(
  embit_gazebo_node_t *node,
  double gx, double gy, double gz
) {
  if (node == NULL || !node->connected) {
    return -1;
  }
  node->gravity_x = gx;
  node->gravity_y = gy;
  node->gravity_z = gz;
  node->world_control_count++;
  return 0;
}

// 查询重力 Z 分量（用于测试验证）
MOONBIT_FFI_EXPORT
double embit_gazebo_get_gravity_z(embit_gazebo_node_t *node) {
  if (node == NULL) {
    return 0.0;
  }
  return node->gravity_z;
}

// 获取世界控制操作计数
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_world_control_count(embit_gazebo_node_t *node) {
  if (node == NULL) {
    return 0;
  }
  return node->world_control_count;
}

// ===== 场景管理 =====

// 生成模型（spawn）
// model_name: UTF-8 编码的模型名
// 返回：0=成功, -1=失败（未连接或空指针）
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_spawn_model(
  embit_gazebo_node_t *node,
  moonbit_bytes_t model_name
) {
  (void)model_name;
  if (node == NULL || !node->connected) {
    return -1;
  }
  node->model_count++;
  return 0;
}

// 删除模型（remove）
// model_name: UTF-8 编码的模型名
// 返回：0=成功, -1=失败（未连接或无模型）
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_remove_model(
  embit_gazebo_node_t *node,
  moonbit_bytes_t model_name
) {
  (void)model_name;
  if (node == NULL || !node->connected || node->model_count <= 0) {
    return -1;
  }
  node->model_count--;
  return 0;
}

// 获取场景中模型数量
// 返回：模型数量，-1=失败
MOONBIT_FFI_EXPORT
int32_t embit_gazebo_model_count(embit_gazebo_node_t *node) {
  if (node == NULL) {
    return -1;
  }
  return node->model_count;
}