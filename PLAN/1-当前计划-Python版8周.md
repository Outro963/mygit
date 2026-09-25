# MyGit（Python 版）· 8 周改进计划 v2

> 这是你原版 8 周计划的**改进版**，不是重写：语言、周数、每天时长、验收标准全部保留。
> 改动集中在三处：**别再污染真实 `.git`**、**用真实 git 当测试 oracle**、**tree/commit 二进制格式的坑提前写清**。
> 远程仓库/登录问题见 `PLAN\2-远程仓库与GitHub登录.md`。
> 工作区：`F:\MyGit`

---

## 0. 这版改了什么（对照原计划）

| # | 原计划 | 改进后 | 为什么 |
|---|---|---|---|
| 1 | 第 1 周 Day 5 写 `init`，创建 `.mygit/objects`、`.mygit/refs`、`HEAD` | 保留，但**加一条铁律**：必须先确认脚本写的是 `.mygit` 而不是 `.git` | 你原来的 `main.py` 写的是 `.git`，已经把你项目仓库的真实 `.git` 破坏成残缺目录（只剩 objects/refs/HEAD，缺 config），我已用 `git init` 修复 |
| 2 | 只靠"自己看输出对不对"验证 | **差分测试**：拿真实 git 当 oracle（`git hash-object`、`git cat-file -p`、`git fsck`） | 你机器上 git 2.55 已装好。这是免费、权威、离线的验证手段，原计划完全没用 |
| 3 | Day 5 写 HEAD：`open("HEAD","w")` | **必须 `open(..., "w", newline="\n")` 或写二进制** | 现场证据：你的 `.git/HEAD` 实际字节是 `...main\r\n`（`0D 0A`），git 在警告 "trailing whitespaces or newlines"。Windows 文本模式会把 `\n` 变成 `\r\n` |
| 4 | 第 4 周"Day 1 理解 tree 对象 / Day 2 write-tree" | 拆细：**20 字节二进制 SHA、mode 写 `40000` 不是 `040000`、目录按 `name/` 参与排序** | 这三个点写错，你的对象真实 git 一律读不了，而且报错在别的命令上，极难自查 |
| 5 | 第 6 周"随机测试对比真实 Git" | 提前到第 2 周就开始做，每周都跑 | 越早建立对拍，越早发现格式错误，不用等到第 6 周返工 |
| 6 | 第 7 周 diff 自己实现 | 可以自己写，也可以先用 `difflib.unified_diff`，再换成自己的实现 | Python 自带，先用它把 `diff` 打通，理解格式后再自己写 |
| 7 | 没有断更规则 | 新增**断更恢复规则 + 每周缓冲日** | 你有考试/竞赛/大创，计划必须能被打断而不崩 |
| 8 | AI 边界 | 保留并补充：允许 AI 写测试用例、解释报错、review；禁止 AI 写 SHA/对象序列化/tree 组装/index 解析/checkout 恢复 | 你原来的边界是对的，我加了一条"提问模板" |
| 9 | 上传 GitHub | 三条路：修 GitHub / Gitee / 本地裸仓库 | 实测你到 `github.com` 的 IP 443 不通，是链路问题不是密码问题 |

---

## 1. 起点校准：你已经完成了哪些（不用从零开始）

实测你的 `main.py`（62 行）：

| 计划中的任务 | 状态 |
|---|---|
| `init`：创建 objects / refs / HEAD | ✅ 已实现 |
| 理解 blob 对象格式 `"blob <len>\0<content>"` | ✅ 已实现 |
| 用 `hashlib.sha1` 算哈希 | ✅ 已实现 |
| `zlib.compress` 写对象到 `objects/xx/yyyy` | ✅ 已实现 |
| `hash-object [-w]` | ✅ 已实现 |
| `argparse` | ❌ 还在手写 `sys.argv` 解析（原计划第 2 周 Day 5） |
| 目录用 `.mygit` 而不是 `.git` | ❌ **要改** |
| 写文本文件用 LF 而不是 CRLF | ❌ **要改** |

**结论**：你的进度大约在原计划的 **第 2 周 Day 3**。Week 1~2 可以加速，省下的时间投到第 4 周（tree/commit 是最容易烂尾的一段）。

**第一件事（20 分钟就能做完）**：

```powershell
cd F:\MyGit
Rename-Item main.py mygit.py
# 打开 mygit.py，把两处 ".git/..." 改成 ".mygit/..."
# 把 open(".mygit/HEAD", "w") 改成 open(".mygit/HEAD", "w", newline="\n")
```

---

## 2. 一条铁律 + 四个必踩的坑

### 铁律
> **`mygit init` 只能在 `test-sandbox\` 里跑。**
> 在 `F:\MyGit` 根目录跑，就会把项目自己的版本控制目录写坏——你已经踩过一次了。

```powershell
mkdir F:\MyGit\test-sandbox -Force
cd F:\MyGit\test-sandbox
python ..\mygit.py init
```

### 坑 1：Windows 文本模式（你已经踩了）
`open(path, "w")` 把 `\n` 写成 `\r\n`。Git 的 `HEAD`、`refs/heads/*` 必须是 **LF**。
→ 统一用 `open(path, "w", newline="\n")`；对象文件一律 `"wb"`。

### 坑 2：读文件必须二进制
`open(f, "r")` 会把 `\r\n` 规范化成 `\n`，哈希必错。→ 一律 `open(f, "rb")`。你已经对了，保持。

### 坑 3：tree 条目的三个细节
1. SHA 是 **20 字节原始二进制**，不是 40 个十六进制字符。→ `bytes.fromhex(sha)`
2. 目录的 mode 写 **`40000`**（5 个字符），不是 `040000`。
3. 排序：目录要按 `名字 + "/"` 参与比较，和普通文件名不同。

写错任何一个，`git cat-file` / `git fsck` 就会拒绝你的对象。

### 坑 4：commit 的元数据格式
```
tree <40位十六进制>
parent <40位十六进制>        ← 首个 commit 没有这一行
author 名字 <邮箱> 1712345678 +0800
committer 名字 <邮箱> 1712345678 +0800

提交信息
```
- `1712345678` 是 **Unix 时间戳（整数秒）**，不是日期字符串。
- 时区是 `+0800` 这种格式，用 `time.strftime("%z")` 得到的是 `+0800`（在中文 Windows 上可能是 `中国标准时间`，需要处理）。

---

## 3. 目录结构与文件规划

```
F:\MyGit\
  mygit.py              # 主入口（第 6 周重构时再拆包）
  tests\
    test_sha.py         # 单元测试（pytest）
    test_objects.py
    test_index.py
    test_oracle.py      # ★ 与真实 git 对拍（本计划新增的核心）
  tools\
    dag.py              # 画提交 DAG
  docs\
    设计笔记.md          # 你自己写的笔记（index 格式、tree 组装算法、遇到的问题）
  test-sandbox\         # 手工试用区（已 gitignore）
  PLAN\                 # 我生成的计划与工具，入口是 PLAN\0-先看这个.md
```

`.mygit/` 布局（和真实 git 一致，除了 index 是 JSON）：
```
.mygit\
  HEAD                  # "ref: refs/heads/main\n"
  objects\ab\cdef...    # zlib 压缩的对象
  refs\heads\main       # 40 位十六进制 SHA
  index                 # 你自己定的格式（JSON 最简单）
  refs\heads\dev
```

---

## 4. 每天 1.5 小时怎么用

| 时间 | 内容 |
|---|---|
| 20 分钟 | 看资料 / 理解概念（只看今天要写的那一个点） |
| 60 分钟 | 写代码（一次只做一个函数） |
| 10 分钟 | 写笔记 + `git add` + `git commit` |
| +5 分钟 | 把明天的第一步写在纸上 |

每周 6 天，第 7 天缓冲。**有考试/竞赛就整周跳过，不自责、不补进度。**

---

## 5. 8 周计划

### 第 1 周：校准 + 补齐工具链认知（原计划大部分已完成）

| 天 | 任务 | 产出 |
|---|---|---|
| D1 | 跑 `PLAN\3-网络体检脚本.ps1`，决定远程仓库路线 | 记录结论 |
| D2 | `main.py` → `mygit.py`；`.git` → `.mygit`；`newline="\n"` | 能跑 `init` |
| D3 | 在 `test-sandbox` 里 `init`，用真实 git 观察 `.mygit` 目录 | 截图/笔记 |
| D4 | 画一张对象关系图：blob / tree / commit / ref / HEAD | 关系图 |
| D5 | 配置 git 身份，提交第一版 | `git log` 有历史 |
| D6 | 复习 + 笔记 | 笔记 |
| D7 | 缓冲 | — |

**检查点**：能用一句话解释"commit 是什么、HEAD 是什么"；`F:\MyGit\.git` 保持健康（`git fsck` 无错）。

### 第 2 周：对象存储 + 对拍（原计划第 2 周 + 新增对拍）

| 天 | 任务 | 产出 |
|---|---|---|
| D1 | 复习 SHA-1 / `hashlib` / zlib 压缩原理 | 笔记 |
| D2 | `cat-file -p <hash>`：读对象并解析头部 | 能读自己的对象 |
| D3 | 错误处理：非法哈希、对象不存在、数据损坏 | 清晰报错 |
| D4 | 用 `argparse` 重写参数解析 | 命令行规范 |
| D5 | **对拍 O1**：`git hash-object f` vs `python mygit.py hash-object f` | 5 个文件全部一致 |
| D6 | **对拍 O2**：`mygit hash-object -w f` 后，把对象拷进临时真实仓库，`git cat-file -p <sha>` | 真实 git 能读你的对象 |
| D7 | 缓冲 | — |

**检查点**
```powershell
cd F:\MyGit\test-sandbox
python ..\mygit.py hash-object -w a.txt
git -C <临时仓库> cat-file -p <sha>      # 输出必须和 a.txt 内容完全一致
```
> **O2 通过意味着你的对象格式与真实 Git 二进制兼容**——这是本项目最有说服力的成果。哈希只取决于未压缩内容，所以 `zlib.compress` 的结果不需要和 git 逐字节相同。

### 第 3 周：index 与 add / status（照原计划）

| 天 | 任务 | 产出 |
|---|---|---|
| D1 | 设计 index 格式：`{路径: {mode, sha, size}}`，写入 `docs\设计笔记.md` | 设计文档 |
| D2 | index 读写（用 `json`；**存相对路径，绝不存绝对路径**） | 能存能读 |
| D3 | `add`：读文件（`rb`）→ 存对象 → 更新 index | `add` 能用 |
| D4 | `status` 第一半：工作区 vs index（untracked / modified / deleted） | 显示 modified |
| D5 | `status` 第二半：index vs HEAD（staged） | 显示 staged |
| D6 | 边界：空文件、二进制文件、子目录、重复 add、删除后再 add | 与真实 git 行为一致 |
| D7 | 缓冲 | — |

**检查点**：`add` 后 `status` 显示 staged；改文件后显示 modified。

### 第 4 周：tree / commit / log（最容易烂尾的一周，按改进版拆细）

| 天 | 任务 | 产出 |
|---|---|---|
| D1 | tree 对象格式精读：`<mode> <name>\0<20字节SHA>`；手画一棵 tree | 结构图 |
| D2 | 把 index 组装成**单层** tree（先只支持根目录） | `write-tree` 能跑 |
| D3 | 递归组装子目录 + **按 name/'/' 排序** | 单层/多层都对 |
| D4 | commit 对象：tree / parent / author / committer / message，**时间戳用整数、时区 `+0800`** | commit 能落盘 |
| D5 | 更新 `refs\heads\<branch>` 和 `HEAD`（`newline="\n"`） | 分支指向 commit |
| D6 | `log`：沿 parent 回溯打印 | `log` 能用 |
| D7 | 缓冲 | — |

**检查点（对拍 O3，强烈建议做）**
```powershell
# 在你的 .mygit 里 commit 后，把 objects 拷进一个真实仓库
Copy-Item F:\MyGit\test-sandbox\.mygit\objects\* <临时仓库>\.git\objects\ -Recurse -Force
git -C <临时仓库> fsck           # 无错误 = 你的 tree/commit 格式完全正确
git -C <临时仓库> cat-file -p <你的commit sha>
```

### 第 5 周：branch 与 checkout（照原计划）

| 天 | 任务 | 产出 |
|---|---|---|
| D1 | 分支 = `refs\heads\` 下的一个文件 | 笔记 |
| D2 | `branch`：创建 / 列出 | 可用 |
| D3 | `checkout`：切换 HEAD（先只改指针，不动文件） | 能切分支 |
| D4 | `checkout`：按目标 commit 的 tree **恢复工作区文件**，并删除目标里没有的文件 | 文件内容正确 |
| D5 | 安全检查：工作区有未提交修改时拒绝切换并提示 | 更安全 |
| D6 | 测试 | 测试通过 |
| D7 | 缓冲 | — |

**检查点**：建 `dev` 分支 → 切换 → 改文件 → 提交 → 切回 `main`，工作区文件内容正确。

### 第 6 周：测试 + 可视化 + 重构（照原计划）

| 天 | 任务 | 产出 |
|---|---|---|
| D1 | 补 pytest：覆盖 init/hash-object/cat-file/index | 测试通过 |
| D2 | 补 pytest：add/status/commit/log/branch/checkout | 测试通过 |
| D3 | **随机操作对拍（O4）**：随机 20 步操作后比对分支指向与文件内容 | 差分测试 |
| D4 | 画提交 DAG：`networkx` + `matplotlib` | PNG 图片 |
| D5 | 重构：拆成 `objects.py` / `index.py` / `repository.py` / `commands.py` | 代码清晰 |
| D6 | 写 README | 别人能跑 |
| D7 | 缓冲 | — |

**检查点**：`python -m pytest -q` 全绿；能画出提交图。

> 画图小坑：matplotlib 默认字体不含中文，标签里用中文会变方块。加一行
> `plt.rcParams['font.sans-serif'] = ['Microsoft YaHei']`。

### 第 7 周：diff + fast-forward merge（照原计划）

| 天 | 任务 | 产出 |
|---|---|---|
| D1 | `diff`：工作区 vs HEAD（先用 `difflib.unified_diff`） | `diff` 能用 |
| D2 | 输出格式整理（可读性） | 好看一点 |
| D3 | 理解 fast-forward merge | 能解释 |
| D4 | `merge`：仅 fast-forward（移动 ref + 更新工作区） | `merge` 能用 |
| D5 | 测试 | 测试通过 |
| D6 | 更新 README + 设计笔记 | 文档 |
| D7 | 缓冲 | — |

**检查点**：两个分支能 fast-forward 合并。

### 第 8 周：收尾 + 复盘（照原计划）

| 天 | 任务 | 产出 |
|---|---|---|
| D1 | 修 bug（用 O4 随机对拍找） | 更稳 |
| D2 | 优化代码 | 更干净 |
| D3 | 录 5 分钟演示 | 视频 |
| D4 | 上传 Gitee（或修好的 GitHub / 本地裸仓库） | 仓库 |
| D5 | 写简历描述 | 项目条目 |
| D6 | 复盘：我学到了什么 | 总结 |
| D7 | 决定下一步（见 §9） | 决策 |

---

## 6. 每周检查点汇总

| 周 | 检查点（可验证） |
|---|---|
| 1 | `python mygit.py init` 在 `test-sandbox` 里建出 `.mygit`；根目录 `.git` 未受损 |
| 2 | `hash-object` 与 `git hash-object` 一致；`git cat-file -p` 能读你写的对象 |
| 3 | `add` 后显示 staged，改文件后显示 modified |
| 4 | **`git fsck` 不报错地接受你的 tree/commit** |
| 5 | 切分支后文件内容正确 |
| 6 | `pytest` 全绿 + 随机对拍通过 + 能画 DAG |
| 7 | `diff` + fast-forward merge 可用 |
| 8 | 有演示、有仓库、有简历描述、有复盘 |

---

## 7. 差分测试：用真实 git 当 oracle（本计划的核心新增）

`tests\test_oracle.py` 的四个测试：

| 编号 | 做法 | 验证 | 周 |
|---|---|---|---|
| O1 | `git hash-object f` == `python mygit.py hash-object f` | blob 格式 + 哈希 | 2 |
| O2 | `mygit hash-object -w` → 对象拷进真实仓库 → `git cat-file -p` | zlib 兼容 | 2 |
| O3 | `.mygit/objects` 拷进真实仓库 → `git fsck` / `git log` / `cat-file` | tree + commit 格式 | 4 |
| O4 | 随机 20 步 `add/commit/branch/checkout`，比对分支 SHA 与工作区内容 | 整体语义 | 6 |

写法要点：
```python
import subprocess, sys, os
MYGIT = [sys.executable, r"F:\MyGit\mygit.py"]

def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)

def test_o1(tmp_path):
    f = tmp_path / "a.txt"
    f.write_bytes(b"hello\n")
    fs = str(f)
    assert run(["git", "hash-object", fs], tmp_path).stdout.strip() \
        == run(MYGIT + ["hash-object", fs], tmp_path).stdout.strip()
```
> 注意：调用真实 git 时要在**临时目录**里操作，别在 `F:\MyGit` 里跑 `git init`。

---

## 8. 断更恢复规则

- 一周被打断 → 直接进下一个缓冲日，**不补进度**。
- 两周以上被打断 → 用第 7 天缓冲日重新跑上一周的检查点，通过就继续，不通过就重做那一周。
- 第 6 周结束时如果还没跑通完整闭环 → 砍掉第 7 周（diff/merge），把时间给核心 7 条命令。**核心闭环 > 附加功能。**
- 不要因为"欠了进度"而跳到后面的周。跳过 tree 格式直接写 checkout 是最典型的烂尾路径。

---

## 9. AI 使用边界

**可以让 AI 做**：解释概念、解释报错、生成测试用例与边界清单、review 代码、写 README 模板、写 `scripts`/`tools` 类辅助脚本。

**不要让 AI 做**：写 `hash-object` / `cat-file` / tree 组装 / commit 序列化 / index 解析 / `checkout` 恢复文件——**这些就是这个项目的全部价值**；也不要让 AI 给你能直接复制粘贴运行的完整实现。

**提问模板**
> "我要实现 `add <path>`：输入是相对路径，输出是更新后的 index。请只问我设计问题，不要给代码。"

**反问模板（当 AI 想直接给代码时）**
> "不要给代码。请列出这个函数必须处理的 5 个边界情况，以及我该怎么设计测试来发现它们。"

---

## 10. 远程仓库

三条路，先跑体检再选：

```powershell
powershell -ExecutionPolicy Bypass -File F:\MyGit\PLAN\3-网络体检脚本.ps1
```

1. **修 GitHub**：换 DNS → 必要时 hosts 指向实测可通的 IP；认证必须用 **PAT 或 SSH key**（密码认证早已被禁用）。
2. **Gitee**：国内稳定，HTTPS 用私人令牌即可。
3. **本地裸仓库**：`git init --bare F:\repos\mygit.git`，练 `push/pull/clone` 原理完全等价。

详细步骤在 `PLAN\2-远程仓库与GitHub登录.md`。

---

## 11. 两个月后的决策表

| 2 个月后的感受 | 建议方向 |
|---|---|
| 喜欢"从零造东西" | 后端 / 基础架构 / 存储 |
| 喜欢测试与自动化 | 测试开发 / DevOps |
| 觉得太底层，更喜欢数据 | 大数据开发 / 数据平台 |
| 编程本身没意思 | 尽早换方向 |

**如果做完 Python 版还想走系统方向**：打开 `PLAN\4-第二阶段C++-暂不打开\计划-C++版16周.md`，用 C++ 只重写 `sha1` + 对象存储两个模块（约 4 周），不要整个重写。那时你已经有概念、有测试、有对拍脚本，成本比现在从零上 C++ 低得多。

---

## 附录 A：命令速查

```powershell
# 试用（只在 test-sandbox 里）
cd F:\MyGit\test-sandbox
python ..\mygit.py init
python ..\mygit.py add a.txt
python ..\mygit.py commit -m "first"
python ..\mygit.py log
python ..\mygit.py branch dev
python ..\mygit.py checkout dev

# 对拍
git hash-object a.txt
python ..\mygit.py hash-object a.txt

# 测试
python -m pytest -q

# 保存进度
git -C F:\MyGit add -A
git -C F:\MyGit commit -m "week3: add/status 完成"
```

## 附录 B：症状 → 原因对照表

| 症状 | 常见原因 |
|---|---|
| `git cat-file` 报 `bad tree object` | 目录 mode 写成了 `040000`，应为 `40000` |
| `git fsck` 报 `tree ... not sorted` | 目录排序没按 `name + "/"` 比较 |
| 哈希和 `git hash-object` 不一致 | 用文本模式读了文件；或头部长度写错；或多写了换行 |
| `git log` 时间显示异常 | 用了日期字符串而不是 Unix 整数时间戳；或时区不是 `+0800` |
| git 警告 `HEAD: trailing whitespaces` | 写 HEAD/refs 时产生了 `\r\n` → 加 `newline="\n"` |
| 切分支后文件没变 | `checkout` 只改了 HEAD，没恢复工作区；或 tree 解析没递归 |
| 项目根目录的 `.git` 又被破坏 | 在根目录跑了 `mygit init`，且脚本里写的是 `.git` |
