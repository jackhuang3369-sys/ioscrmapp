# Core ML 模型重训练指南

## 一、已完成的工作

### 1. 对齐本地模型标签空间并扩充运营商业务样本

| 文件 | 更新内容 |
|------|----------|
| `IntentModels.swift` | 本地模型标签集与业务枚举保持一致，覆盖 `data/voice/sms` 查询 |
| `IntentRecognitionService.swift` | 远端 AI prompt 与本地标签集对齐 |
| `LocalIntentMatcher.swift` | 补强套餐/支付/账单/语音/短信边界规则与 typo 归一化 |
| `IntentClassifierServicing.swift` | 模型版本提升到 `2.2` |

### 2. v3.0 语义区分增强 (2026-05-05)

核心问题：CoreML 文本分类器难以区分 **QUERY（查看）** vs **PURCHASE（订购）**：

- "how many sms do i have left" → 误判为 `subscribe_offer`
- "i want to buy an sms package" → 误判为 `sms_usage_query`

解决方案：

1. 扩充英文训练数据（+89 条新样本，聚焦语义区分）
2. 新增 `semantic_distinction_samples.json`（8 组对比 pair 训练）
3. 合并脚本 `merge_and_retrain.py` 自动去重并导出
4. 新增大量短信、流量、语音查询 vs 订阅的对比样本

| 文件 | 路径 | 内容 |
|------|------|------|
| 语义区分样本 | `ML/training_data/semantic_distinction_samples.json` | 纯英文，查询 vs 订购对比训练 |
| 合并脚本 | `ML/training_data/merge_and_retrain.py` | 合并 v2 + 语义样本 → 去重 → 导出 v3 |
| 训练数据集 v3 | `ML/training_data/intent_training_data_v3.json` | 18 种意图，520 条样本 |
| 训练 CSV | `ML/training_data/training_data_v3.csv` | CreateML 训练用 CSV |
| 训练脚本 | `ML/TrainIntentClassifier_v2.swift` | 权威 Swift/CreateML 训练入口 |
| 兼容入口 | `ML/train_intent_classifier.py` | 仅作为 wrapper 委托到 Swift 训练器 |

---

## 二、下一步操作

### Step 1: 合并新样本（已完成）

```bash
cd ioscrmapp/ioscrmapp/ML/training_data
python3 merge_and_retrain.py
```

生成 `intent_training_data_v3.json` + `training_data_v3.csv`

### Step 2: 使用统一训练入口

```bash
cd ioscrmapp/ioscrmapp/ML
python3 train_intent_classifier.py
```

说明：

- `train_intent_classifier.py` 只是兼容入口，会委托到 `TrainIntentClassifier_v2.swift`
- 权威训练数据源为 `training_data/intent_training_data_v3.json`
- 当前训练集以英文样本为主（351 条），重点覆盖运营商核心业务

### Step 3: 替换模型文件

```bash
# 生成的新模型
IntentClassifier_v3.mlmodel

# 替换现有模型
cp IntentClassifier_v3.mlmodel IntentClassifier.mlmodel
```

### Step 4: 更新模型描述符

如果模型版本变更，更新 `IntentClassifierServicing.swift`:

```swift
struct IntentModelDescriptor: Sendable, Equatable {
    static let current = IntentModelDescriptor(
        resourceName: "IntentClassifier",
        version: "3.0"  // 更新版本号
    )
}
```

---

## 三、训练数据样本统计

### v3.0 (2026-05-05)

| 意图类型 | 英文 | 中文 | 阿拉伯语 | 总计 | vs v2 |
|----------|------|------|----------|------|-------|
| sms_usage_query | **49** | 5 | 4 | **58** | +29 |
| data_usage_query | **50** | 15 | 5 | **70** | +12 |
| voice_usage_query | **33** | 5 | 4 | **42** | +13 |
| subscribe_offer | **41** | 4 | 2 | **47** | +20 |
| view_offers | **33** | 5 | 3 | **41** | +15 |
| balance_inquiry | **25** | 5 | 3 | 33 | +9 |
| recharge_account | **28** | 5 | 3 | 36 | +12 |
| itinerary_query | **22** | 9 | 4 | 35 | +10 |
| view_bill | 20 | 4 | 2 | 26 | 不变 |
| account_help | 18 | 4 | 2 | 24 | 不变 |
| make_payment | 14 | 4 | 2 | 20 | 不变 |
| payment_history | 13 | 3 | 2 | 18 | 不变 |
| payment_status | 13 | 2 | 1 | 16 | 不变 |
| flight_info | 5 | 3 | 2 | 10 | 不变 |
| hotel_info | 3 | 2 | 2 | 7 | 不变 |
| general_question | 5 | 3 | 2 | 10 | 不变 |
| navigation_intent | 5 | 4 | 3 | 12 | 不变 |
| unknown | 5 | 0 | 0 | 5 | 不变 |
| **总计** | **382** | **82** | **46** | **510** | **+128** |

### 语义区分对比训练（Critical Contrast Pairs）

| 用户输入 | 正确意图 | 常见误判 |
|----------|----------|----------|
| "how many sms do i have left" | sms_usage_query | subscribe_offer |
| "i want to buy an sms package" | subscribe_offer | sms_usage_query |
| "show me available sms packages" | view_offers | subscribe_offer |
| "i ran out of sms, i want to buy more" | sms_usage_query + subscribe_offer | 单意图 |
| "check my remaining data" | data_usage_query | subscribe_offer |
| "i need more minutes, buy a pack" | voice_usage_query + subscribe_offer | 单意图 |
| "what sms plans do you have" | view_offers | subscribe_offer |
| "i want to see my sms usage" | sms_usage_query | view_offers |

---

## 四、线上意图决策流

当前意图识别按三层职责分工：

1. `LocalIntentMatcher` 负责高确定性规则。命中 `confidence >= 0.85` 的本地规则时，`IntentSignalFusion` 直接采用 rule 结果，不再因 CoreML 冲突触发远端 AI。
2. `CoreMLIntentClassifier` 负责模糊中间地带。规则未命中或置信度不足时，CoreML 提供候选；与本地中低置信规则一致时融合，不一致时按配置进入 AI fallback 或确认。
3. 远端 AI 只处理真正复杂语义。包括多轮上下文、混合意图、结构化实体抽取、或 rule/CoreML 都无法稳定覆盖的请求。

测试分层：

- `must-hit`：明确短句必须本地高置信命中，例如 `check my sms`、`what about my data package`
- `must-not-hit`：泛化词不能误吞随机文本
- `boundary`：相邻业务边界必须稳定，例如 `my data package` 是 usage，`need a bigger data package` 是 subscribe

---

## 五、运营商业务域组织

| 业务域 | 训练意图 |
|--------|----------|
| Usage & Balance | `balance_inquiry`, `data_usage_query`, `voice_usage_query`, `sms_usage_query` |
| Recharge & Credit | `recharge_account` |
| Offers & Subscription | `view_offers`, `subscribe_offer` |
| Billing & Payment | `view_bill`, `make_payment`, `payment_history`, `payment_status` |
| Account Support | `account_help`, `navigation_intent`, `general_question`, `unknown` |
| Auxiliary Non-Telecom | `itinerary_query`, `flight_info`, `hotel_info` |

---

## 六、模型架构说明

```
IntentClassifier.mlmodel (Core ML 文本分类器)

输入: text (String) - 用户输入文本
输出: label (String) - 意图类型 raw value

支持的意图类型 (18种):
├── balance_inquiry
├── data_usage_query
├── voice_usage_query
├── sms_usage_query
├── recharge_account
├── view_offers
├── subscribe_offer
├── view_bill
├── account_help
├── make_payment
├── payment_history
├── payment_status
├── itinerary_query
├── flight_info
├── hotel_info
├── general_question
├── navigation_intent
└── unknown
```

---

## 七、置信度配置

训练完成后，建议调整置信度阈值：

```swift
// IntentClassifierConfiguration
minimumAcceptedCoreMLConfidence: 0.8  // Core ML 单独置信度
minimumAcceptedFusedConfidence: 0.75  // 融合后置信度
```

---

## 八、验证清单

- [ ] 运行合并脚本 `python3 merge_and_retrain.py`
- [ ] 运行训练脚本 `swift TrainIntentClassifier_v2.swift training_data_v3.csv`
- [ ] 检查训练输出（准确率、混淆矩阵）
- [ ] 替换模型文件 `cp IntentClassifier_v3.mlmodel IntentClassifier.mlmodel`
- [ ] 编译项目验证无错误
- [ ] 运行 CoreMLIntentClassifierTests
- [ ] 测试 "how many sms do i have left" → 预期 `sms_usage_query`
- [ ] 测试 "i want to buy an sms package" → 预期 `subscribe_offer`
- [ ] 测试 "show me available sms packages" → 预期 `view_offers`
- [ ] 验证 "check my data package is enough or not" → `data_usage_query`
- [ ] 切换 rolloutMode 为 fusedAuthoritative
- [ ] 生产环境验证

---

## 九、后续持续优化策略

1. **收集真实用户输入** → 标注 → 加入训练数据
2. **Shadow mode A/B** → 新模型 shadow 运行，对比 remote AI，准确率提升后上线
3. **用户反馈闭环** → 用户选择意图时，捕捉 (text, predicted, actual) 加入下一轮训练

---

**创建日期**: 2026-05-03
**最后更新**: 2026-05-05
**版本**: IntentClassifier v3.0
