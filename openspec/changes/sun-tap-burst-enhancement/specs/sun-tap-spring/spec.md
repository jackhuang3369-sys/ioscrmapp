## ADDED Requirements

### Requirement: Sun moves to center with spring overshoot
点击太阳后，太阳入场动画 SHALL 先以 easeInEaseOut 曲线移动至轻微越过中心终点的过冲位置，再以 easeOut 曲线弹回终点，全程使用 SCNAction.sequence 实现，不引入 CASpringAnimation。

#### Scenario: Overshoot occurs before settle
- **WHEN** 用户点击太阳触发入场动画
- **THEN** 太阳在到达 detailSunPosition y=−0.04 之前，先经过 y≈−0.22 的过冲位置，再弹回

#### Scenario: Total overshoot is subtle
- **WHEN** 计算过冲量相对全程移动距离的比例
- **THEN** 过冲比例约 4%（0.18 / 4.44），视觉上"一点点"弹回，不夸张

#### Scenario: Scale also overshoots
- **WHEN** 太阳执行入场动画
- **THEN** scale 先收缩至约 0.82（轻微多缩），再弹回到最终 detailSunScale = 0.84

### Requirement: Spring animation uses SCNAction only
太阳入场 spring 效果 SHALL 完全使用 SCNAction.sequence + SCNAction.move 实现，不使用 CASpringAnimation 或直接操作 presentation layer。

#### Scenario: No CASpringAnimation
- **WHEN** 审查 runSunExpansionAnimation 实现
- **THEN** 代码中不存在 CASpringAnimation 引用，仅使用 SCNAction

### Requirement: Animation timing
完整入场动画（含弹回）总时长 SHALL 约为 0.56s：主段 0.46s（easeInEaseOut）+ 弹回段 0.10s（easeOut）。

#### Scenario: Main phase timing
- **WHEN** 太阳开始移动
- **THEN** 在约 0.46s 时到达过冲位置

#### Scenario: Bounce phase timing
- **WHEN** 太阳到达过冲位置
- **THEN** 在约 0.10s 内弹回至 detailSunPosition 并停止
