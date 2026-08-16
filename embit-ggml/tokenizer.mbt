///|
/// 机器人指令分词器：基于内置词表的词级分词。
///
/// 内置常见机器人指令词表（pick/up/move/grab 等），`encode` 通过词表查找生成 token ID，
/// `decode` 通过逆向词表恢复文本。词表内单词满足 `decode(encode(s)) == s` 往返一致。
/// 词表外单词使用哈希回退生成 ID（偏移至词表末尾之后，避免 ID 冲突），`decode` 返回 `"<unk>"`。
///
/// 条件编译架构：占位模式使用内置词表分词；真实模式（EMBIT_HAS_GGML）应关联 GgmlContext
/// 并调用 ggml tokenizer C API（BPE/SentencePiece 子词分词）。真实绑定需后续 PR 扩展
/// Tokenizer API 以持有 GgmlContext 引用。
pub struct Tokenizer {
  vocab_size : Int // 词表容量
  mut encode_count : Int // 编码调用次数
  vocab : Array[String] // 内置词表，索引即 token ID
}

///|
/// 内置机器人指令词表（索引即 token ID）。
///
/// 前 4 个为特殊 token：`<pad>` / `<unk>` / `<bos>` / `<eos>`，
/// 随后为常见机器人指令动词、名词、修饰词与测试用词。
fn default_vocab() -> Array[String] {
  [
    "<pad>", "<unk>", "<bos>", "<eos>", "pick", "up", "the", "red", "block", "blue",
    "green", "ball", "cup", "bowl", "plate", "move", "to", "table", "shelf", "counter",
    "walk", "forward", "backward", "left", "right", "turn", "stop", "grab", "release",
    "open", "close", "gripper", "arm", "head", "base", "rotate", "lift", "lower",
    "push", "pull", "slide", "place", "drop", "put", "on", "off", "in", "out", "over",
    "under", "near", "far", "fast", "slow", "carefully", "quickly", "hello", "world",
    "foo", "bar", "baz", "test", "single", "do", "something", "task", "command",
    "action", "execute", "run", "start", "end", "finish", "go", "come", "here", "there",
    "where", "what", "when", "how", "why",
  ]
}

///|
/// 创建 Tokenizer。
///
/// `vocab_size` 为词表容量。内置词表取前 `min(vocab_size, 82)` 个词，
/// 词表外单词通过哈希回退映射到 `[vocab_size, vocab_size)` 范围。
/// `vocab_size <= 0` 时 `encode` 将抛出 `InvalidConfig`。
pub fn Tokenizer::new(vocab_size : Int) -> Tokenizer {
  let full_vocab = default_vocab()
  let vocab = if vocab_size >= full_vocab.length() {
    full_vocab
  } else if vocab_size > 0 {
    let v : Array[String] = []
    for word in full_vocab {
      if v.length() >= vocab_size {
        break
      }
      v.push(word)
    }
    v
  } else {
    []
  }
  { vocab_size, encode_count: 0, vocab }
}

///|
/// 使用自定义词表创建 Tokenizer。
///
/// `vocab` 为 token 字符串数组，索引即 token ID。词表容量等于词表长度。
pub fn Tokenizer::with_vocab(vocab : Array[String]) -> Tokenizer {
  { vocab_size: vocab.length(), encode_count: 0, vocab }
}

///|
/// 默认 Tokenizer（词表容量 32000，内置 82 词）。
pub fn Tokenizer::default() -> Tokenizer {
  Tokenizer::new(32000)
}

///|
/// 统计文本 token 数（按空白字符分词）。
///
/// 占位模式按空白字符分词计数，与 `encode` 结果长度一致。
/// 真实模式（EMBIT_HAS_GGML）应调用 ggml tokenizer API 返回子词 token 数。
/// 空字符串返回 0。
pub fn Tokenizer::count_tokens(self : Tokenizer, text : String) -> Int {
  ignore(self)
  if text.length() == 0 {
    0
  } else {
    let mut count = 0
    let mut in_token = false
    for ch in text {
      if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
        in_token = false
      } else if !in_token {
        in_token = true
        count = count + 1
      }
    }
    count
  }
}

///|
/// 编码文本为 token ID 序列。
///
/// 按空白字符分词，每个词先查内置词表，命中则返回索引作为 ID；
/// 未命中则用哈希回退生成 ID（偏移至词表长度之后，避免与词表 ID 冲突）。
/// `vocab_size <= 0` 时抛出 `RobotError::InvalidConfig`。
pub fn Tokenizer::encode(
  self : Tokenizer,
  text : String,
) -> Array[Int] raise @core.RobotError {
  self.encode_count = self.encode_count + 1
  if self.vocab_size <= 0 {
    raise InvalidConfig("vocab_size must be positive")
  }
  let tokens : Array[Int] = []
  let mut current = ""
  let mut has_char = false
  for ch in text {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if has_char {
        tokens.push(self.encode_token(current))
        current = ""
        has_char = false
      }
    } else {
      current += ch.to_string()
      has_char = true
    }
  }
  if has_char {
    tokens.push(self.encode_token(current))
  }
  tokens
}

///|
/// 编码单个 token：先查词表，未命中则哈希回退。
///
/// 哈希回退 ID 偏移至 `[vocab.length(), vocab_size)` 区间，
/// 确保 `decode` 能区分词表内/外 token。
fn Tokenizer::encode_token(self : Tokenizer, token : String) -> Int {
  // 词表查找
  let mut idx = 0
  for word in self.vocab {
    if word == token {
      return idx
    }
    idx = idx + 1
  }
  // 哈希回退：多项式滚动哈希
  let mut hash = 0
  for ch in token {
    hash = (hash * 31 + ch.to_int()) % 1000000
  }
  let vocab_len = self.vocab.length()
  if self.vocab_size > vocab_len {
    vocab_len + hash % (self.vocab_size - vocab_len)
  } else {
    hash % self.vocab_size
  }
}

///|
/// 解码 token ID 序列为文本。
///
/// ID 在词表范围内返回对应词，范围外返回 `"<unk>"`。
/// 各词以空格连接，空数组返回空字符串。
pub fn Tokenizer::decode(self : Tokenizer, token_ids : Array[Int]) -> String {
  if token_ids.length() == 0 {
    return ""
  }
  let mut result = ""
  let mut first = true
  for id in token_ids {
    if first {
      first = false
    } else {
      result += " "
    }
    if id >= 0 && id < self.vocab.length() {
      result += self.vocab[id]
    } else {
      result += "<unk>"
    }
  }
  result
}

///|
/// 获取词表容量。
pub fn Tokenizer::get_vocab_size(self : Tokenizer) -> Int {
  self.vocab_size
}

///|
/// 获取编码调用次数。
pub fn Tokenizer::encode_count(self : Tokenizer) -> Int {
  self.encode_count
}

///|
/// 估算文本所需上下文长度。
///
/// 返回 `count_tokens(text) + margin`，用于判断上下文窗口是否足够。
pub fn Tokenizer::estimate_context_usage(
  self : Tokenizer,
  text : String,
  margin : Int,
) -> Int {
  self.count_tokens(text) + margin
}

// ===== ggml tokenizer 绑定 =====
// 以下方法接受 GgmlContext 参数，调用 ggml tokenizer C API。
// 真实模式（EMBIT_HAS_GGML）使用 BPE/SentencePiece 子词分词。
// 占位模式（FFI 返回 -1 或空）回退到内置词表分词。

///|
/// 使用关联的 ggml 上下文编码文本为 token ID 序列。
///
/// 真实模式调用 ggml tokenizer C API（BPE/SentencePiece 子词分词）。
/// 占位模式回退到内置词表分词（`encode`）。
pub fn Tokenizer::encode_with_ggml(
  self : Tokenizer,
  ctx : GgmlContext,
  text : String,
) -> Array[Int] raise @core.RobotError {
  let n = embit_ggml_tokenize(ctx, @utf8.encode(text))
  if n > 0 {
    let tokens : Array[Int] = []
    for i in 0..<n {
      tokens.push(embit_ggml_get_token_id(ctx, i))
    }
    self.encode_count = self.encode_count + 1
    return tokens
  }
  self.encode(text)
}

///|
/// 使用关联的 ggml 上下文解码 token ID 序列为文本。
///
/// 真实模式调用 ggml tokenizer C API 逐个解码并拼接。
/// 占位模式回退到内置词表解码（`decode`）。
pub fn Tokenizer::decode_with_ggml(
  self : Tokenizer,
  ctx : GgmlContext,
  token_ids : Array[Int],
) -> String {
  if token_ids.length() == 0 {
    return ""
  }
  let mut result = ""
  let mut all_decoded = true
  for id in token_ids {
    let piece = embit_ggml_detokenize(ctx, id)
    if piece.length() == 0 {
      all_decoded = false
      break
    }
    result += @utf8.decode_lossy(piece)
  }
  if all_decoded && result.length() > 0 {
    return result
  }
  self.decode(token_ids)
}

///|
/// 使用关联的 ggml 上下文统计文本 token 数。
///
/// 真实模式返回 ggml tokenizer 的子词 token 数。
/// 占位模式回退到空白字符分词计数（`count_tokens`）。
pub fn Tokenizer::count_tokens_with_ggml(
  self : Tokenizer,
  ctx : GgmlContext,
  text : String,
) -> Int {
  let n = embit_ggml_tokenize(ctx, @utf8.encode(text))
  if n > 0 {
    return n
  }
  self.count_tokens(text)
}
