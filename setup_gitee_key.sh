#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
#  为 Gitee 生成密钥 + 写正确的 ~/.ssh/config + 验证
#
#  修正了原脚本的三个问题：
#   ① 致命：Host 别名叫 rmbbiji，但更新脚本连的是 git@gitee.com，
#      Host 段只对「实际连接的主机名」生效，别名根本不会被匹配到，
#      ssh 会退回使用 ~/.ssh 下的默认密钥 → Permission denied (publickey)。
#      现在按真实主机名写：gitee.com 与 ssh.gitee.com（443 回退要用后者）。
#   ② 验证方式：ssh -T 会误导（部署公钥下显示 Hi Anonymous! 看似失败，
#      而且它根本不测仓库权限）。改为 git ls-remote，与 clone 走同一条链路。
#   ③ 直接追加到 config 末尾会被 Host * 压掉（OpenSSH 对同一参数取
#      第一个匹配到的值），现在插到兜底段之前；并加备份、幂等处理。
# ===================================================================

# ===== 可改参数 =====
KEY="${GITEE_SSH_KEY:-$HOME/.ssh/rmbbiji_gitee}"   # 私钥路径（公钥为 $KEY.pub）
COMMENT="rmbbiji@gitee"                            # 公钥注释
HOSTS="gitee.com ssh.gitee.com"                    # 必须写主机名，不能写自定义别名
REPO="${GITEE_REPO:-git@gitee.com:rmbbiji/short_cuts.git}"   # 用于验证的真实仓库
# ===================

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# ---------- 1) 生成密钥（已存在则跳过，避免覆盖） ----------
if [ -f "$KEY" ]; then
    echo "==> 已存在私钥，跳过生成：${KEY}"
else
    echo "==> 生成 ed25519 密钥：${KEY}"
    ssh-keygen -t ed25519 -C "$COMMENT" -f "$KEY" -N ""
fi
chmod 600 "$KEY"
if [ -f "$KEY.pub" ]; then
    chmod 644 "$KEY.pub"
fi

# ---------- 2) 备份并整理 ~/.ssh/config ----------
CFG="$HOME/.ssh/config"
touch "$CFG"
chmod 600 "$CFG"
BACKUP="$CFG.bak.$(date +%Y%m%d%H%M%S)"
cp -a "$CFG" "$BACKUP"
echo "==> 已备份旧配置：${BACKUP}"

tmp_cur="$(mktemp)"
tmp_new="$(mktemp)"
cp "$CFG" "$tmp_cur"

# 删除任何以目标主机名为 pattern 的 Host 段。
# 目的是避免「同名 Host 段重复出现」——OpenSSH 先到先得，残留的旧段会让新配置失效。
drop_host_block() {
    awk -v t="$1" '
        BEGIN { keep = 1 }
        $1 == "Host" {
            drop = 0
            for (i = 2; i <= NF; i++) if ($i == t) drop = 1
            keep = drop ? 0 : 1
            if (keep) print
            next
        }
        $1 == "Match" { keep = 1; print; next }
        { if (keep) print }
    ' "$2" > "$3"
}

for h in $HOSTS; do
    drop_host_block "$h" "$tmp_cur" "$tmp_new"
    mv "$tmp_new" "$tmp_cur"
done

# 清掉上一次生成的标记注释行（Host 段已被上面按主机名删掉，这里清残留的注释），
# 否则每跑一次就会多堆一组标记行。用 awk 而非 grep，避免「整文件都被过滤掉」时
# grep 返回非 0 触发 set -e。
MARK_BEGIN="# >>> gitee setup script managed block >>>"
MARK_END="# <<< gitee setup script managed block <<<"
awk -v b="$MARK_BEGIN" -v e="$MARK_END" '$0 != b && $0 != e' "$tmp_cur" > "$tmp_new"
mv "$tmp_new" "$tmp_cur"

# 折叠连续空行：删段落后会在原位置留下空行，不处理的话每跑一次就多一行
squeeze_blank_lines() {
    awk '
        /^[[:space:]]*$/ { if (blank) next; blank = 1; print; next }
        { blank = 0; print }
    ' "$1" > "$2"
}
squeeze_blank_lines "$tmp_cur" "$tmp_new"
mv "$tmp_new" "$tmp_cur"

# 去掉末尾空行，保证幂等
strip_trailing_blanks() {
    awk '
        { line[NR] = $0 }
        END {
            last = NR
            while (last > 0 && line[last] ~ /^[[:space:]]*$/) last--
            for (i = 1; i <= last; i++) print line[i]
        }
    ' "$1" > "$2"
}
strip_trailing_blanks "$tmp_cur" "$tmp_new"
mv "$tmp_new" "$tmp_cur"

# ---------- 组装托管块 ----------
block_file="$(mktemp)"
cat > "$block_file" <<EOF
${MARK_BEGIN}
Host gitee.com
  HostName gitee.com
  User git
  IdentityFile ${KEY}
  IdentitiesOnly yes

Host ssh.gitee.com
  HostName ssh.gitee.com
  User git
  Port 443
  IdentityFile ${KEY}
  IdentitiesOnly yes
${MARK_END}
EOF

# ---------- 插入位置：第一个兜底段（Host * / Host *.* / Match …）之前 ----------
# 若直接追加到文件末尾，而你的 config 里有定义了 IdentityFile 的 Host * 段，
# 新加的这段会被完全忽略（先到先得）。实测过这个坑。
tmp_out="$(mktemp)"
awk -v blockfile="$block_file" '
    # prev_blank 记录上一行的状态：只有前一行不是空行时才补一个空行做分隔，
    # 否则重复执行会稳定地多出一个空行（不报错，但很脏）。
    function emit(   l) {
        if (!prev_blank) print ""
        while ((getline l < blockfile) > 0) print l
        close(blockfile)
    }
    BEGIN { inserted = 0; prev_blank = 1 }
    {
        if (!inserted && ($1 == "Host" || $1 == "Match")) {
            catchall = 1
            if ($1 == "Host") {
                for (i = 2; i <= NF; i++) if ($i != "*" && $i != "*.*") catchall = 0
            }
            if (catchall) { emit(); inserted = 1 }
        }
        print
        prev_blank = ($0 ~ /^[[:space:]]*$/)
    }
    END { if (!inserted) emit() }
' "$tmp_cur" > "$tmp_out"
mv "$tmp_out" "$tmp_cur"
rm -f "$block_file"

cp "$tmp_cur" "$CFG"
chmod 600 "$CFG"
rm -f "$tmp_cur" "$tmp_new"

echo "==> 已写入 Host ${HOSTS}（指向 ${KEY}）"

# ---------- 3) 打印公钥 ----------
echo
echo "================== 复制下面这一整行，加到 Gitee =================="
if [ -f "$KEY.pub" ]; then
    cat "$KEY.pub"
else
    ssh-keygen -y -f "$KEY"
fi
echo "=================================================================="
echo
echo "加到哪："
echo "  · 账号公钥：个人设置 → 安全设置 → SSH 公钥 → 添加公钥（账号下所有仓库可读写）"
echo "  · 部署公钥：short_cuts 仓库 → 管理 → 部署公钥管理 → 添加部署公钥"
echo "    ⚠️ 部署公钥只对「加了它的那一个仓库」有效，必须加在 short_cuts 上。"
echo

# ---------- 4) 验证 ----------
echo "==================== 验证 ===================="
echo "连接 gitee.com 实际会用到："
ssh -F "$CFG" -G gitee.com 2>/dev/null | grep -i "^identityfile" | sed 's/^/  /' || echo "  （无）"

effective_key="$(ssh -F "$CFG" -G gitee.com 2>/dev/null | awk 'tolower($1) == "identityfile" { print $2; exit }')"
if [ "$effective_key" = "$KEY" ]; then
    echo "  ✅ 首个生效的私钥正是目标密钥。"
else
    echo "  ⚠️  首个生效的是 ${effective_key:-（无）}，不是目标密钥。"
    echo "     说明更靠前的 Host 段里定义了 IdentityFile，请把 managed block 手动移到它之前。"
fi
echo

echo "仓库可访问性测试（这才是脚本真正用的判定方式）："
if GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new -i $KEY -o IdentitiesOnly=yes" \
     git ls-remote --heads "$REPO" >/dev/null 2>&1; then
    echo "  ✅ 通过，可以运行更新脚本了："
    echo "     bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/update_short_cuts_gitee.sh)\""
else
    echo "  ❌ 失败，请检查：公钥是否完整添加、是否加在 short_cuts 仓库上、部署公钥是否已启用。"
    echo "     若 22 端口被机房封锁，更新脚本会自动回退到 Gitee 官方 443 通道。"
fi
echo
echo "（附：ssh -T git@gitee.com 的输出仅作参考，不要用它的成败下结论——"
echo "  部署公钥下它会显示 Hi Anonymous!，那是正常的。）"
echo
echo "如需回滚配置：cp -a ${BACKUP} ${CFG}"
