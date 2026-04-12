# iOSCRM 双机开发与仓库同步工作流

## 1. 背景与目标

当前网络条件：
- Windows 电脑：可访问公司内网仓库 `origin`，也可访问 Gitee。
- MacBook：只能访问 Gitee。

目标：
- 保持 `main` 分支在 `origin` 与 `gitee` 间一致。
- 让你在公司内外都能连续开发。
- 降低冲突与误操作风险。

---

## 2. 远程与职责分工

- `origin`：公司内网仓库（权威主仓）。
- `gitee`：公网仓库（外网开发入口）。

职责：
- Windows = 桥接机（负责 `origin <-> gitee` 同步）。
- MacBook = 外网开发机（只和 `gitee` 交互）。

---

## 3. 分支约定

- 长期分支：`main`
- 功能分支：`feature/<topic>`
- 修复分支：`bugfix/<topic>`

建议：
- 不在 `main` 长期直接开发。
- 每个需求独立分支，完成后合并到 `main`。

---

## 4. 一次性配置

### 4.1 Windows（已具备 origin，补充 gitee）

```bash
git remote -v
git remote add gitee https://gitee.com/scylla/ioscrmapp.git
```

如果已经添加过 `gitee`，可跳过 `add`。

### 4.2 MacBook（只配置 gitee）

```bash
git clone https://gitee.com/scylla/ioscrmapp.git
cd ioscrmapp
git remote -v
```

确保不要把 `origin`（内网地址）配置到 MacBook。

---

## 5. 每天最小操作清单

## 5.1 每天开始前

### Windows

```bash
git checkout main
git fetch origin
git pull --rebase origin main
git push gitee main
```

说明：先从内网拿最新，再同步给 Gitee，保证 MacBook 可见最新主线。

### MacBook

```bash
git checkout main
git fetch gitee
git pull --rebase gitee main
```

---

## 5.2 开发中

### 任一设备（推荐）

```bash
git checkout -b feature/<topic>
# 开发 + 提交
git push -u gitee feature/<topic>
```

说明：
- 外网开发统一推到 `gitee`。
- 如果公司流程要求，也可在 Windows 再推同名分支到 `origin`。

---

## 5.3 需求完成后

可选两种方式：

- 方式 A（推荐）：在 Gitee 提 PR，合并到 `main`。
- 方式 B：本地合并后直接推 `gitee/main`。

完成后在 Windows 做桥接回流：

```bash
git fetch gitee
git checkout main
git pull --rebase gitee main
git push origin main
```

说明：把你在外网完成的结果回灌到公司内网主仓。

---

## 5.4 每天下班前

在 Windows 执行一次最终对齐：

```bash
git checkout main
git pull --rebase origin main
git push gitee main
```

如当天主要在 MacBook 开发，先执行第 5.3 节的回流步骤，再做这一步。

---

## 6. 常见检查命令

```bash
git remote -v
git branch -vv
git status --short --branch
git ls-remote --heads gitee
git ls-remote --heads origin
```

判定要点：
- 两端都能看到 `refs/heads/main`。
- `main` 提交号一致时表示已同步。

---

## 7. 风险控制建议

- 禁止对 `main` 使用 `--force`。
- 推送前先 `pull --rebase`，减少无意义 merge。
- 大资源文件变更多时，优先在单设备集中处理，减少冲突。
- `.gitignore` 已包含本地构建产物规则，避免再次提交临时文件。

---

## 8. 根目录目录说明

以下为仓库根目录下各目录作用：

- `.git/`
  - Git 元数据目录，包含提交历史、分支引用、对象库与配置。
  - 仅供 Git 使用，不应手动编辑。

- `build/`
  - 本地或工具生成的构建中间产物目录。
  - 通常不应纳入版本控制，已在 `.gitignore` 规则中覆盖。

- `docs/`
  - 项目文档目录，存放流程说明、打包说明、截图等。
  - 当前包含 iOS 打包相关文档与图片。

- `ioscrmapp/`
  - 应用主工程源码目录。
  - 包含业务模块、组件、资源、配置、服务层与本地化文件。

- `ioscrmapp.xcodeproj/`
  - Xcode 工程定义目录。
  - 包含项目配置、scheme、workspace 关联等工程元信息。

- `SmokeTests/`
  - 冒烟测试代码目录。
  - 用于覆盖关键主流程可用性验证。

- `Task/`
  - 任务与实施计划目录。
  - 存放任务说明、实施计划和辅助文件。

---

## 9. 推荐别名（可选，仅 Windows）

可配置一个桥接别名，减少重复输入：

```bash
git config alias.sync-main "!git checkout main && git pull --rebase origin main && git push gitee main"
```

之后执行：

```bash
git sync-main
```

即可完成内网到公网主线同步。
