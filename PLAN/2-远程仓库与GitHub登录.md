# GitHub 登录失败 / 远程仓库 排查与修复

> 结论先行：**你的密码很可能没写错。** 实测数据显示，你的机器到 `github.com` 的 443 端口**连不上**，这是链路问题；而且即便修好网页登录，`git push` **也不能用账号密码**（GitHub 2021-08-13 起已禁用密码认证）。

---

## 一、实测数据（2026 年在本机测得）

| 目标 | 结果 | 说明 |
|---|---|---|
| DNS `github.com` | `20.205.243.166` | 解析正常 |
| TCP `github.com:443` | ❌ **不通** | ← 你在浏览器里遇到的"登录一直失败"最可能的直接原因 |
| TCP `api.github.com:443` | ✅ 通 | |
| TCP `codeload.github.com:443` | ✅ 通 | |
| TCP `gitee.com:443` | ✅ 通 | Gitee 可用 |
| TCP `140.82.112.3:443` | ✅ 通 | GitHub 的美国 IP，可用 |
| TCP `140.82.113.4:443` | ✅ 通 | 可用 |
| TCP `140.82.121.4:443` | ✅ 通 | 可用 |
| `C:\Windows\...\etc\hosts` | 无 github 相关条目 | 说明不是 hosts 写的坏 IP |
| 系统代理 | `ProxyEnable=0`（未启用），但残留配置 `127.0.0.1:10792` | 端口实测**无人监听** |
| 本地常见代理端口 7890/7897/10809/1080/8080 | 全部无人监听 | 你没有在跑代理软件 |

**解读**：`github.com` 解析出的那个 IP 被阻断了，但 GitHub 的**其他 IP 是通的**。这就是典型的"能打开一半、登录提交表单时被重置"——表现形式经常就是网页提示账号或密码错误，或一直转圈/验证码加载不出来。

> 说明：TLS 层测试我这边环境跑不了（沙箱里 schannel 不可用，连百度都报同一个错），所以上表只用了可信的裸 TCP 结论。你在自己的终端里跑 `PLAN\3-网络体检脚本.ps1` 能得到完整的 TLS/HTTP 结果。

---

## 二、按顺序做（大概率第 3 步就好了）

### 第 1 步：跑一次体检

```powershell
powershell -ExecutionPolicy Bypass -File F:\MyGit\PLAN\3-网络体检脚本.ps1
```

### 第 2 步：换 DNS + 清缓存

```powershell
# 查看当前 DNS
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses

# 图形界面改更稳：设置 → 网络和 Internet → 以太网/WLAN → DNS 服务器分配 → 手动
#   首选 223.5.5.5（阿里）   备用 119.29.29.29（腾讯）

ipconfig /flushdns
```

改完先只测这个：
```powershell
Test-NetConnection github.com -Port 443 -InformationLevel Quiet
```
出现 `True` 就可以去浏览器试登录了。

### 第 3 步：还不行就把 github.com 指到实测可通的 IP

用**管理员权限**打开 PowerShell：

```powershell
$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
Copy-Item $hosts "$hosts.bak" -Force          # 先备份
Add-Content $hosts "`n140.82.112.3 github.com"
Add-Content $hosts "140.82.113.4 api.github.com"
Add-Content $hosts "140.82.113.4 codeload.github.com"
ipconfig /flushdns
```

再测：
```powershell
Test-NetConnection github.com -Port 443 -InformationLevel Quiet
curl.exe -I https://github.com/login --max-time 20
```

⚠️ 注意：GitHub 的 IP 会变，某个 IP 哪天不通了，换 `140.82.121.4` 或删掉 hosts 那几行。**不要长期依赖 hosts**，它只是应急。你机器上 hosts 现在是干净的，这是好事。

### 第 4 步：能打开网页了，但登录仍报"账号或密码错误"

这时才轮到真正的凭据问题，逐条排：

1. **用无痕窗口（Ctrl+Shift+N）登录**。浏览器扩展或密码管理器自动填充旧密码是极常见原因。
2. **确认用户名**：GitHub 登录框接受用户名或邮箱，但两者都必须是你注册时用的那个。注意全角字符、前后空格、输入法没切回来。
3. **验证码加载不出来**：GitHub 登录带人机验证，如果验证码脚本被阻断，你会看到"登录失败"而不是"验证码失败"。表现就是密码明明对却登不上——**这是你这台机器最可能的情况**，回到第 2/3 步解决网络。
4. **走"忘记密码"**：`https://github.com/password_reset`。如果邮箱收不到重置邮件（也翻垃圾箱），说明账号或邮箱本身有问题。
5. **新账号邮箱未验证**：注册后 GitHub 要求点确认邮件。邮箱没验证会导致很多操作失败，去垃圾箱找 `noreply@github.com`。
6. **账号被标记**：少数情况 GitHub 会要求额外验证或限制登录，页面上会有说明。

---

## 三、关键：修好网页登录也**不能**用密码 push

GitHub 从 2021-08-13 起就**禁用了密码认证 git 操作**。所以：

### 方案 A：Personal Access Token（HTTPS，最快）

1. 浏览器打开 `https://github.com/settings/tokens` → **Generate new token (classic)**
2. Note 写 `mygit-laptop`，Expiration 选 90 天，勾选 **`repo`** 权限 → 生成
3. **立刻复制 token**（只显示一次）
4. 用 token 当密码：

```powershell
git config --global credential.helper manager   # Windows 用 GCM，凭据只输一次
cd F:\MyGit
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
# 提示 Username 填用户名，Password 粘贴 token（不是账号密码！）
```

### 方案 B：SSH Key（推荐，一次配好永久用）

```powershell
ssh-keygen -t ed25519 -C "你的邮箱"        # 一路回车，密码可留空
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub   # 复制这一整行
```
浏览器 → `https://github.com/settings/keys` → **New SSH key** → 粘贴 → 保存。

**你的网络下建议让 SSH 走 443 端口**（22 端口常被封）。编辑或新建 `$env:USERPROFILE\.ssh\config`：

```
Host github.com
    HostName ssh.github.com
    Port 443
    User git
```

测试：
```powershell
ssh -T git@github.com     # 出现 "Hi <用户名>! You've successfully authenticated" 即成功
git remote add origin git@github.com:<用户名>/<仓库名>.git
```

### 方案 C：Gitee（国内最省事，推荐先用它）

1. 注册/登录 `https://gitee.com`
2. 右上角头像 → 设置 → **私人令牌** → 生成令牌（勾 `projects`）
3. ```powershell
   git remote add origin https://gitee.com/<用户名>/<仓库名>.git
   git push -u origin main   # 用户名 + 私人令牌当密码
   ```

### 方案 D：本地裸仓库（完全离线，等价练习）

网络怎么都不通也能练 `push/pull/clone` 的全部原理：

```powershell
git init --bare F:\repos\mygit.git
cd F:\MyGit
git remote add origin F:\repos\mygit.git
git push -u origin main
git clone F:\repos\mygit.git F:\tmp\clone-test   # 验证 clone 真的能用
```

---

## 四、浏览器登录常见误区速查

| 现象 | 真实原因 |
|---|---|
| "Incorrect username or password" 但密码确认无误 | 链路被重置 / 验证码加载失败 / 扩展自动填充旧密码 |
| 页面一直转圈，最后超时 | `github.com:443` 被阻断（你当前的情况） |
| 能打开仓库页但登录按钮无反应 | 前端资源（`github.githubassets.com`）被阻断 |
| 密码重置邮件收不到 | 邮箱错 / 邮件在垃圾箱 / 邮箱未验证 |
| 一直要求"验证身份" | 新设备 + 网络多变，GitHub 风控 |
