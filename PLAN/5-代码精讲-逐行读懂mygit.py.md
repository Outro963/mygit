# 代码精讲① · 逐行读懂 mygit.py（62 行）

> **我们的约定**：代码我写，但每一行都讲清「在干嘛」和「为什么必须这样」，同时补 Git 基础。
> **读法**：先看「做什么」，再看「为什么」。带 ⚠️ 的是坑，带 📌 的是必须记住的结论。
> 文档里的所有哈希、字节数都是**实测**的（用你机器上真实的 git 交叉验证过）。

---

## 0. 总纲：Git 到底是什么

📌 **一句话：Git 是一个「内容寻址的键值数据库」，外加几个几十字节的指针文件。**

| | 内容 |
|---|---|
| **键** | 内容的 SHA-1 哈希（40 个十六进制字符） |
| **值** | 内容本身（zlib 压缩后存盘） |
| **数据库** | `.git/objects/`（我们用 `.mygit/objects/`） |
| **指针** | `.git/refs/` 和 `.git/HEAD` |

这个设计白送你三件好处：

1. **天然去重** —— 内容一样 → 哈希一样 → 只存一份（同一个文件存 100 次，磁盘上只有 1 个对象）
2. **天然防篡改** —— 任何一个字节变了，哈希就变，名字对不上
3. **分支极廉价** —— 一个分支就是一个 40 字节的文件（所以 Git 鼓励你随便开分支）

---

## 1. 五种东西，先把名字和关系记住

```
        HEAD（文件，内容 = "ref: refs/heads/main"）
          │  ← 回答"我现在在哪个分支"
          ▼
   refs/heads/main（文件，内容 = 某个 commit 的哈希）
          │
          ▼
       commit ──parent──▶ commit ──parent──▶ commit（最早的那个，没有 parent）
          │                                        ← 这就是 DAG（有向无环图）
          ▼
        tree（一层目录：模式 + 文件名 + 指向 blob 的哈希）
        ├── blob   （文件的内容）
        └── tree   （子目录，递归下去）
```

| 名字 | 是什么 | 关键点 |
|---|---|---|
| **blob** | 文件**内容** | ⚠️ **不含文件名！** |
| **tree** | 一层目录的快照 | 记录「模式 + 名字 + 20 字节哈希」 |
| **commit** | 一次提交 | 指向 1 个 tree + 0~n 个 parent + 作者/时间/说明 |
| **ref** | 指向 commit 的**可变**名字 | 分支 = `refs/heads/` 下的一个文件 |
| **HEAD** | 指向 ref 的指针 | 也就是"你当前在哪" |
| **index** | 暂存区（还没做） | Week 3 才写，是"下次 commit 的候选清单" |

📌 **最容易搞混的一点**：blob 里**没有文件名**。文件名存在 tree 里。
所以把 `a.txt` 改名成 `b.txt`，**不会**产生新 blob（内容没变），只会产生新的 tree —— 这就是 Git 省空间的核心原因。

---

## 2. 逐行精讲

### 第 1~4 行：四个工具箱

| 行 | 代码 | 在干嘛 | 为什么是它 |
|---|---|---|---|
| 1 | `import os` | 文件和目录操作 | 后面用 `makedirs` 建目录、`getcwd` 取当前路径、`path.dirname` 取父目录 |
| 2 | `import sys` | 和命令行打交道 | `sys.argv` 取参数，`sys.exit` 返回**退出码** |
| 3 | `import hashlib` | 哈希算法库 | SHA-1 就是 Git 给对象命名用的算法 |
| 4 | `import zlib` | DEFLATE 压缩 | Git 把对象压缩后存盘，用的就是这个容器格式 |

> Python 有现成的 `hashlib`/`zlib` 就直接用——**这正是 Python 版比 C++ 版省掉 200 行的原因**（C++ 得自己实现 SHA-1 和 deflate）。

---

### 第 6~15 行：`cmd_init()` —— 造一个空仓库

```python
6:  def cmd_init():          #模拟初始化仓库
7:      # 创建目录，exist_ok=True 表示已存在也不报错
8:      os.makedirs(".mygit/objects", exist_ok=True)      # 存放所有文件快照（Git 对象库）
9:      os.makedirs(".mygit/refs/heads", exist_ok=True)   # 存放分支指针
10:
11:     # HEAD 是一个文本文件，指向当前分支
12:     with open(".mygit/HEAD", "w", newline="\n") as f:
13:         f.write("ref: refs/heads/main\n")
14:
15:     print(f"Initialized empty MyGit repository in {os.getcwd()}/.mygit")
```

**第 8 行** `os.makedirs(".mygit/objects", exist_ok=True)`
- 做什么：建 `objects/` 目录——就是上面说的**哈希数据库**。
- 为什么 `exist_ok=True`：让 `init` **可以反复执行**（幂等）。真实 git 的 `git init` 也能跑很多次，第二次只会提示 "Reinitialized existing"。

**第 9 行** `os.makedirs(".mygit/refs/heads", exist_ok=True)`
- 做什么：建分支目录。
- 📌 **推论（很重要）**：一个分支 = 这个目录下的**一个文件**，文件名就是分支名，文件内容就是一个 commit 的哈希。所以：
  - 「创建分支」= 写一个文件
  - 「列出分支」= 列目录
  - 「删除分支」= 删文件
  - 「切换分支」= 改 HEAD 的内容
  
  这就是为什么 Git 开分支几乎不花时间——它没有复制任何文件。

**第 12 行** `with open(".mygit/HEAD", "w", newline="\n") as f:`
- `"w"` = 文本写模式（文件不存在就创建，存在就清空）。
- `newline="\n"` ⚠️ **必须加**：Windows 下 Python 默认会把 `\n` 写成 `\r\n`。Git 的元数据文件必须是 LF，否则 git 会警告 `trailing whitespaces`。（详见第 4 节，这是你真实踩过的坑。）
- `with ... as f:` 是**上下文管理器**：代码块结束时自动关闭文件，即使中间报错也会关。所以不需要手动 `f.close()`。

**第 13 行** `f.write("ref: refs/heads/main\n")`
- 做什么：写入 HEAD 的内容。
- 📌 这叫**符号引用**（symbolic ref）：HEAD **不直接存哈希**，而是存"我指向哪个 ref 文件"。
- 为什么这么设计：只要你在 main 分支，以后每次 commit 都只需要更新 `refs/heads/main`，HEAD 自动跟着走，不用每次改两个地方。
- ⚠️ 注意：此刻 `refs/heads/main` 这个文件**还不存在**！这是正常状态——HEAD 指向一个"还没出生"的分支，**第一次 commit 时才会创建它**。
- 对比理解：如果 HEAD 里直接写 40 位哈希（没有 `ref: ` 前缀），那就是**分离头指针**（detached HEAD），此时 commit 不会推进任何分支。

**第 15 行** `print(f"...{os.getcwd()}/.mygit")`
- `f"..."` 是 f-string：`{}` 里的表达式会被求值后拼进字符串。
- `os.getcwd()` = current working directory，当前所在目录的绝对路径。真实 git 也会打印这个。

---

### 第 17~46 行：`cmd_hash_object(args)` —— 算哈希 / 存对象

```python
17: def cmd_hash_object(args):
18:     # 解析 -w 选项
19:     write = False
20:     if args and args[0] == "-w":
21:         write = True
22:         args = args[1:]
23:
24:     if not args:
25:         print("usage: mygit hash-object [-w] <file>")
26:         sys.exit(1)
27:
28:     filename = args[0]
29:     with open(filename, "rb") as f:      # 注意 rb：二进制模式
30:         data = f.read()
31:
32:     #构造 blob 对象： "blob <size>\0<content>"
33:     header = f"blob {len(data)}\0".encode()
34:     store = header + data
35:
36:     #算 SHA-1
37:     sha = hashlib.sha1(store).hexdigest()
38:
39:     #如果加了 -w，就写到磁盘
40:     if write:
41:         path = f".mygit/objects/{sha[:2]}/{sha[2:]}"
42:         os.makedirs(os.path.dirname(path), exist_ok=True)
43:         with open(path, "wb") as f:
44:             f.write(zlib.compress(store))
45:
46:     print(sha)
```

**第 20 行** `if args and args[0] == "-w":`
- `args and ...`：**先判空再取下标**。如果直接写 `args[0]`，参数为空时会抛 `IndexError`。这是 Python 里最常见的防御写法。
- ⚠️ 局限：只认"第一个参数是 `-w`"。`mygit hash-object a.txt -w` 这种写法不认。Week 2 会用 `argparse` 重写成规范版本。

**第 24~26 行** 没给文件名 → 打印用法 + `sys.exit(1)`
- `sys.exit(1)` 里的 `1` 是**退出码**：0 表示成功，非 0 表示失败。终端和 CI 靠它判断你的程序有没有出错。

**第 29~30 行** `open(filename, "rb")` ⚠️
- **`rb` = read binary，二进制模式。必须用！**
- 文本模式 `"r"` 会把 `\r\n` 规范化成 `\n`，字节一变，哈希就错。**Git 处理的是字节，不是文本。**
- `data` 的类型是 `bytes`（不是 `str`）。

**第 33 行** `header = f"blob {len(data)}\0".encode()`
- 核心公式第一步：`<类型> <字节长度>\0`
- `\0` 是 **NUL 字节**（0x00），不是可打印字符，用作分隔符。
- `.encode()`：把 `str` 转成 `bytes`。Python 的 `str` 是 Unicode 文本，写到磁盘前必须显式编码（默认 UTF-8）。
- 📌 `len(data)` 是**字节数**，不是字符数。一个中文字符在 UTF-8 里是 3 字节。

**第 34 行** `store = header + data`
- 📌 **对象的完整定义**：`类型 + 空格 + 字节长度 + NUL + 原始内容`
- 为什么要把类型和长度写进去？解压之后你手上只有一串字节，必须靠元信息知道"这是什么对象、内容从哪开始"；长度还能用来校验数据有没有被截断。

**第 37 行** `sha = hashlib.sha1(store).hexdigest()`
- 对象名 = SHA-1(**未压缩**的 `store`)，取十六进制字符串。
- 📌 **先哈希、后压缩**，这是整个项目最关键的一点：压缩算法/级别/实现怎么变，对象名都不变 → 所以**你的实现能和真实 git 对拍**。
- `hexdigest()` 返回 40 个字符；`digest()` 返回 20 字节原始值（写 tree 时要用原始值）。

**第 40 行** `if write:`
- 只有带 `-w` 才写盘。不带 `-w` 时只"算"不"存"——和真实 `git hash-object` 的行为一致。

**第 41 行** `path = f".mygit/objects/{sha[:2]}/{sha[2:]}"`
- 📌 **松散对象路径 = `objects/<哈希前2位>/<剩下38位>`**
- `sha[:2]` 是切片：前 2 个字符；`sha[2:]` 是从第 2 个字符到末尾。
- 例：`ce013625...` → `.mygit/objects/ce/013625030ba8dba906f756967f9e9ca394464a`
- 为什么要分目录：一个仓库可能有几十万个对象，全塞进一个目录会让文件系统变慢。用前 2 位（十六进制 → 256 个目录）把文件分散开。
- 真实 git 也是这个规则（虽然 git 还支持"打包文件 packfile"，那是优化，你不需要做）。

**第 42 行** `os.makedirs(os.path.dirname(path), exist_ok=True)`
- 取路径的父目录（`.../objects/ce`）并创建。

**第 43~44 行** `open(path, "wb")` + `zlib.compress(store)`
- `wb` = write binary，二进制写。
- zlib 容器 = **2 字节头 + DEFLATE 数据 + 4 字节 adler32 校验**。实测：`"hello\n"` 压缩后 21 字节，开头是 `78 9c`。
- 真实 git 用**同一个容器格式** → 所以 `git cat-file -p <你的对象>` 能读出来。（这是 Week 2 的验收点。）

**第 46 行** `print(sha)` —— 输出哈希，和 `git hash-object` 行为一致。

---

### 第 48~62 行：`main()` —— 命令分发

```python
48: def main():
49:     if len(sys.argv) < 2:
50:         print("usage: mygit <command> [<args>]")
51:         sys.exit(1)#立即结束程序，并返回退出码1
52:
53:     command = sys.argv[1]
54:     if command == "init":
55:         cmd_init()
56:     elif command == "hash-object":              # ← 新增这两行
57:         cmd_hash_object(sys.argv[2:])
58:     else:
59:         print(f"mygit: '{command}' is not a mygit command")
60:
61: if __name__ == "__main__":
62:     main()
```

**第 49~51 行** 没给命令 → 打印用法 + 退出码 1
- `sys.argv` 是一个列表：`["mygit.py", "hash-object", "-w", "a.txt"]`。`sys.argv[0]` 永远是**脚本名本身**，所以真参数从索引 1 开始。

**第 53 行** `command = sys.argv[1]` —— 第一个真参数就是命令名。

**第 54~59 行** 命令分发（if / elif 链）
- 真实 git 是一个二进制里塞了几百个子命令，原理和这个 if 链**完全一样**。
- 第 57 行 `sys.argv[2:]`：切片，把"命令之后的所有参数"整体传给子函数。
- ⚠️ 第 59 行有个**小瑕疵**：遇到未知命令只打印，**没有 `sys.exit(1)`**。真实 git 会返回非 0 退出码。记下来，Week 2 换 argparse 时一起修。

**第 61~62 行** `if __name__ == "__main__": main()`
- 📌 `__name__` 是 Python 给每个文件自动设的变量：**直接运行**这个文件时它等于 `"__main__"`；被别的文件 `import` 时它等于模块名。
- 所以这行的意思是："只有直接运行我才执行 main()，被 import 时不执行"。**测试代码 import 你的模块时，就靠这个不触发主流程。**

---

## 3. 一个完整例子（数字全部实测）

文件内容 `hello` + 换行（6 字节），走一遍你代码的每一步：

| 步骤 | 代码 | 实际结果 |
|---|---|---|
| 读文件 | `open(f,"rb").read()` | `b"hello\n"`（6 字节） |
| 造头 | `f"blob {len(data)}\0".encode()` | `b'blob 6\x00'` → 十六进制 `62 6c 6f 62 20 36 00` |
| 拼接 | `header + data` | 13 字节 |
| 哈希 | `sha1(store).hexdigest()` | **`ce013625030ba8dba906f756967f9e9ca394464a`** |
| 压缩 | `zlib.compress(store)` | 21 字节，开头 `78 9c 4b ca` |
| 落盘 | `objects/{sha[:2]}/{sha[2:]}` | `.mygit/objects/ce/013625030ba8dba906f756967f9e9ca394464a` |

另外两个实测值（记住这两个，以后测试用）：

| 内容 | 对象名（SHA-1） |
|---|---|
| **空文件**（0 字节） | `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` |
| `abc`（3 字节，无换行） | `f2ba8f84ab5c1bce84a7b441cb1959cfc7093b7f` |

**交叉验证结果**（三种内容，你的实现 vs 真实 git）：

```
hello.txt   git=ce013625030ba8dba906f756967f9e9ca394464a  mygit=ce013625030ba8dba906f756967f9e9ca394464a  MATCH
empty.txt   git=e69de29bb2d1d6434b8b29ae775ad8c2e48c5391  mygit=e69de29bb2d1d6434b8b29ae775ad8c2e48c5391  MATCH
abc.txt     git=f2ba8f84ab5c1bce84a7b441cb1959cfc7093b7f  mygit=f2ba8f84ab5c1bce84a7b441cb1959cfc7093b7f  MATCH
```

📌 **这就是计划里的「对拍 O1」——已经通过了。**

---

## 4. 我替你改的那 5 处，逐处解释

| # | 位置 | 改前 | 改后 | 为什么 |
|---|---|---|---|---|
| 1 | 文件名 | `main.py` | `mygit.py` | 计划里的验收命令写的是 `python mygit.py ...`，名字统一 |
| 2 | 第 8、9 行 | `.git/objects`、`.git/refs/heads` | `.mygit/...` | ⚠️ **你踩过的真实事故**（见下） |
| 3 | 第 12 行 | `open(...,"w")` | `open(...,"w",newline="\n")` | 见下 |
| 4 | 第 15 行 | 提示文字里的 `.git` | `.mygit` | 跟着改，不然打印信息骗人 |
| 5 | 第 41 行 | `.git/objects/...` | `.mygit/objects/...` | 不改的话，对象会被写进**真实 .git**，污染你的版本控制库 |

**第 2 处为什么是事故**：真实 git 用 `.git` 目录存自己的数据。你的脚本也用 `.git` 的话，`python mygit.py init` 会在项目根目录创建一个**假的 `.git`**，把真实的版本控制目录搞坏。你的仓库当时确实坏了——`.git` 里只剩下 `objects/refs/HEAD`，跑 `git config` 报：

```
fatal: unable to read config file '.git/config': No such file or directory
```

改成 `.mygit` 之后，两套系统各用各的目录，互不干扰。

**第 3 处为什么必须加 `newline="\n"`**：你原来那个 `.git/HEAD` 的实测字节是

```
... 6D 61 69 6E 0D 0A      ← "main" + \r\n
```

git 每次都在警告 `HEAD: trailingRefContent: has trailing whitespaces or newlines`。加了 `newline="\n"` 之后的实测字节：

```
... 6D 61 69 6E 0A         ← "main" + \n   ✅
```

---

## 5. 自测 8 问（先自己答，再看箭头后面）

1. blob 里存不存文件名？ → **不存。** 文件名在 tree 里。所以改名不产生新 blob。
2. 为什么要先算哈希、再压缩？ → 这样压缩实现/级别不影响对象名，任何实现都能算出同一个名字（这就是能和 git 对拍的原理）。
3. `HEAD` 里写 `ref: refs/heads/main` 和直接写一个哈希，区别是什么？ → 前者是**指向分支**（新 commit 会自动跟进）；后者是**分离头指针**（detached HEAD）。
4. 空文件的 blob 哈希是多少？为什么所有空文件共享同一个对象？ → `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391`；因为对象名只由内容决定，内容相同必然同名。
5. 对象为什么要按哈希前 2 位分目录？ → 减少单个目录下的文件数量，避免文件系统性能退化。
6. 对象头里为什么要写长度？ → 解压后要知道内容从哪开始，并且能校验是否被截断。
7. 为什么读文件必须用 `"rb"`？ → 文本模式会改行尾字节，哈希必错。
8. `sys.exit(1)` 里的 1 是什么意思？ → 退出码。0 = 成功，非 0 = 失败，供 shell/脚本/CI 判断。

---

## 6. 下一步（`cat-file`）需要补的知识

Week 2 Day 2 要写的 `cat-file -p <hash>` 就是把上面的过程**反过来**，需要四样东西：

| 需要的知识 | 对应代码思路 |
|---|---|
| `zlib.decompress` | 把磁盘上的对象还原成 `store` |
| 找 NUL 分界 | `store.split(b"\0", 1)` → `[b"blob 6", b"hello\n"]` |
| 解析类型和长度 | `header.split(b" ")` → `[b"blob", b"6"]` |
| 校验 | `len(content)` 必须等于头的长度，否则报「对象损坏」 |

再加一个错误处理：对象文件不存在时要报清楚（而不是让 Python 弹一个 `FileNotFoundError` 堆栈）。

---

*本文档由 AI 生成，所有数字均已用你机器上的真实 git 验证。*
