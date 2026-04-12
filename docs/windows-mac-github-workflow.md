# iOSCRM 双机开发与仓库同步工作流

## 1. 背景与目标

当前网络条件：
- Windows 电脑：可访问公司内网仓库 `origin`，也可访问 GitHub。
- MacBook：只能访问 GitHub。

目标：
- 保持 `main` 分支在 `origin` 与 `github` 间一致。
- 让你在公司内外都能连续开发。
- 降低冲突与误操作风险。

---

## 2. 远程与职责分工

- `origin`：公司内网仓库（权威主仓）。
- `github`：公网仓库（外网开发入口）。

职责：
- Windows = 桥接机（负责 `origin <-> github` 同步）。
- MacBook = 外网开发机（只和 `github` 交互）。

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

### 4.1 Windows（已具备 origin，补充 github）

```bash
git remote -v
git remote add github git@github.com:scyllor/ioscrmapp.git
```

如果已经添加过 `github`，可跳过 `add`。

推荐直接使用 SSH 地址，避免大仓库通过 HTTPS 首次推送时因连接重置而失败。

```bash
git remote set-url github git@github.com:scyllor/ioscrmapp.git
```

切换前提：
- Windows 本机已生成 SSH 公钥。
- 该公钥已添加到 GitHub 账号的 SSH keys 设置中。

### 4.2 MacBook（只配置 github）

```bash
git clone git@github.com:scyllor/ioscrmapp.git
cd ioscrmapp
git remote -v
```

确保不要把 `origin`（内网地址）配置到 MacBook。

如果 MacBook 尚未配置 SSH，也可以先用 HTTPS clone，后续再切到 SSH。

---

## 4.3 推荐 SSH 初始化

### Windows 查看现有公钥

```powershell
Get-Content $HOME\.ssh\id_rsa.pub
```

### MacBook 查看现有公钥

```bash
cat ~/.ssh/id_rsa.pub
```

将公钥复制到 GitHub 后，测试 SSH 是否可用：

```bash
ssh -T git@github.com
```

若返回欢迎或认证成功提示，即可正常走 SSH 推送。

---

## 5. 每天最小操作清单

## 5.1 每天开始前

### Windows

```bash
git checkout main
git fetch origin
git pull --rebase origin main
git push github main
```

说明：先从内网拿最新，再同步给 GitHub，保证 MacBook 可见最新主线。

### MacBook

```bash
git checkout main
git fetch github
git pull --rebase github main
```

---

## 5.2 开发中

### 任一设备（推荐）

```bash
git checkout -b feature/<topic>
# 开发 + 提交
git push -u github feature/<topic>
```

说明：
- 外网开发统一推到 `github`。
- 如果公司流程要求，也可在 Windows 再推同名分支到 `origin`。

---

## 5.3 需求完成后

可选两种方式：

- 方式 A（推荐）：在 GitHub 提 PR，合并到 `main`。
- 方式 B：本地合并后直接推 `github/main`。

完成后在 Windows 做桥接回流：

```bash
git fetch github
git checkout main
git pull --rebase github main
git push origin main
```

说明：把你在外网完成的结果回灌到公司内网主仓。

---

## 5.4 每天下班前

在 Windows 执行一次最终对齐：

```bash
git checkout main
git pull --rebase origin main
git push github main
```

如当天主要在 MacBook 开发，先执行第 5.3 节的回流步骤，再做这一步。

---

## 6. 常见检查命令

```bash
git remote -v
git branch -vv
git status --short --branch
git ls-remote --heads github
git ls-remote --heads origin
```

判定要点：
- 两端都能看到 `refs/heads/main`。
- `main` 提交号一致时表示已同步。

---

## 7. 首次公网同步故障排查

### 7.1 典型失败现象

如果首次推送到 GitHub 时出现类似输出：

```text
error: RPC failed; curl 55 Send failure: Connection was reset
send-pack: unexpected disconnect while reading sideband packet
fatal: the remote end hung up unexpectedly
```

通常表示：
- 认证不一定有问题。
- 仓库在通过 HTTPS 首次全量上传时，连接被中途重置。
- 常见于大 pack、低速网络、长连接不稳定场景。

### 7.2 先确认是不是真的推送失败

```bash
git ls-remote --heads github main
git rev-parse main
```

判定方法：
- 如果 `git ls-remote --heads github main` 没有输出，说明远端还没有 `main`。
- 不要被 `Everything up-to-date` 误导，这种情况下它不代表远端已经成功创建主分支。

### 7.3 优先解决方案

优先改用 SSH：

```bash
git remote set-url github git@github.com:scyllor/ioscrmapp.git
git push -u github main
```

这是当前仓库最稳妥的公网同步方式。

### 7.4 如果暂时只能走 HTTPS

可以尝试以下命令降低连接被重置的概率：

```powershell
$env:GIT_TERMINAL_PROMPT='0'
git -c http.version=HTTP/1.1 -c http.lowSpeedLimit=0 -c http.lowSpeedTime=999999 push -u github main
Remove-Item Env:GIT_TERMINAL_PROMPT
```

注意：
- 这只是缓解，不如 SSH 稳定。
- 仓库首次推送包较大时，仍可能失败。

### 7.5 为什么首次推送会慢

当前仓库历史中包含一些不应长期保留的构建产物和用户态文件，例如：
- `build/` 下的 Xcode 构建数据
- `xcuserdata` 相关文件
- `ioscrmapp/Modules/Weather/WeatherData/OBJ/night9.obj` 这类较大的 3D 资源文件

它们虽然已被 `.gitignore` 覆盖，但历史提交仍然包含这些对象，因此首次推送体积仍然偏大。

---

## 8. Git LFS 配置建议

当前仓库已经触发过 GitHub 大文件告警，建议尽快将后续新增的大资源改由 Git LFS 管理，尤其是：
- `*.obj`
- `*.glb`
- `*.usdz`
- `*.exr`
- 可能持续增长的高精度贴图、音频、设计源文件

### 8.1 安装 Git LFS

Windows：

```powershell
git lfs install
```

MacBook：

```bash
git lfs install
```

### 8.2 为仓库启用常见大文件类型

在仓库根目录执行：

```bash
git lfs track "*.obj"
git lfs track "*.glb"
git lfs track "*.usdz"
git lfs track "*.exr"
git lfs track "*.psd"
git lfs track "*.sketch"
```

这会生成或更新 `.gitattributes`。

### 8.3 提交 LFS 规则

```bash
git add .gitattributes
git commit -m "chore: configure git lfs tracking"
```

### 8.4 让新文件走 LFS

对新加入仓库的大文件，正常 `git add` 和 `git commit` 即可，Git 会自动将内容存入 LFS。

### 8.5 已经提交过的大文件怎么办

Git LFS 只会影响后续被重新加入版本控制的文件，不会自动改写历史。

如果你要把历史中的大文件迁移到 LFS，需要额外执行历史重写，例如：

```bash
git lfs migrate import --include="*.obj,*.glb,*.usdz,*.exr"
```

注意：
- 这会改写提交历史。
- 会影响 `origin`、`github` 以及其他开发机器。
- 在当前已有内网仓库和 GitHub 远程的前提下，不建议未经统一安排直接执行。

更稳妥的策略是：
- 先为后续新增大文件启用 LFS。
- 历史迁移另开一次专门操作窗口处理。

---

## 9. 风险控制建议

- 禁止对 `main` 使用 `--force`。
- 推送前先 `pull --rebase`，减少无意义 merge。
- 大资源文件变更多时，优先在单设备集中处理，减少冲突。
- `.gitignore` 已包含本地构建产物规则，避免再次提交临时文件。

---

## 10. 根目录目录说明

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

## 11. 推荐别名（可选，仅 Windows）

可配置一个桥接别名，减少重复输入：

```bash
git config alias.sync-main "!git checkout main && git pull --rebase origin main && git push github main"
```

之后执行：

```bash
git sync-main
```

即可完成内网到 GitHub 主线同步。
