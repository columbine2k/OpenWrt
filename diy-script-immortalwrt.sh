#!/bin/bash

# ============================================================
# diy-script-immortalwrt：基于 ImmortalWrt openwrt-25.12 的定制脚本
#
# 与 diy-script.sh（LEDE）完全独立，互不干扰：
#   - 上游文件修改一律做成补丁放在 patches-immortalwrt/*.patch，
#     本脚本统一用 git apply 应用
#   - 只有批量/动态改动保留为脚本：插件克隆、Makefile 批量重写、
#     编译日期版本号、主题默认值清理
# ============================================================

# 移除要替换的包（ImmortalWrt luci feed 同样自带这些包）
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf feeds/luci/applications/luci-app-netdata
rm -rf feeds/luci/applications/luci-app-argon-config

# 可选开关（默认关闭，需要时取消注释）
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" || {
    echo "ERROR: 克隆失败 $repourl" >&2
    exit 1
  }
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd "$repodir" || {
    echo "ERROR: 进入目录失败 $repodir" >&2
    exit 1
  }
  git sparse-checkout set "$@" || {
    echo "ERROR: 稀疏检出失败 $repourl ($*)" >&2
    exit 1
  }
  mv -f "$@" ../package || {
    echo "ERROR: 移动 $* 到 package/ 失败" >&2
    exit 1
  }
  cd .. && rm -rf "$repodir"
}

# 添加额外插件
git clone --depth=1 https://github.com/esirplayground/luci-app-poweroff package/luci-app-poweroff || exit 1
git clone --depth=1 https://github.com/Jason6111/luci-app-netdata package/luci-app-netdata || exit 1

# Themes
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon || exit 1
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config || exit 1

# 在线用户
git_sparse_clone main https://github.com/haiibo/packages luci-app-onliner
chmod 755 package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh

# 编译日期版本号（动态内容，不能写成静态补丁）。
# ImmortalWrt 的 default-settings 不写 DISTRIB_REVISION，
# 因此用独立 uci-defaults 在首次开机时写入 /etc/openwrt_release
date_version=$(date +"%y.%m.%d")
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-immortalwrt-version <<EOF
#!/bin/sh
# SohWrt (ImmortalWrt) 编译日期版本号
sed -i '/^DISTRIB_REVISION=/d' /etc/openwrt_release
echo "DISTRIB_REVISION='R${date_version}'" >> /etc/openwrt_release
exit 0
EOF
chmod +x files/etc/uci-defaults/99-immortalwrt-version

# 批量 Makefile 重写（面向多个动态克隆的包，保留脚本方式）
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# 取消主题默认设置（批量处理所有主题，保留脚本方式）
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

./scripts/feeds update -a
./scripts/feeds install -a

# —— 统一应用补丁（patches-immortalwrt/*.patch，路径相对 openwrt 根目录）——
# 已应用过的补丁会被 git apply --reverse --check 识别并跳过，重复构建安全；
# 真正冲突的补丁会直接报错退出，避免“悄悄漏改”
_patch_dir="$GITHUB_WORKSPACE/patches-immortalwrt"
for _patch in "$_patch_dir"/*.patch; do
	[ -f "$_patch" ] || continue
	echo "Applying $(basename "$_patch")"
	if (cd "$OPENWRT_PATH" && git apply --reverse --check "$_patch" >/dev/null 2>&1); then
		echo "  already applied, skip"
	elif (cd "$OPENWRT_PATH" && git apply "$_patch"); then
		:
	else
		echo "ERROR: failed to apply $_patch" >&2
		exit 1
	fi
done

# hostapd / dockerd 的补丁走 OpenWrt 包自身的 patches/ 机制
# （构建对应包时自动应用），因此单独复制而不是在上面的循环里打
cp -f $GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch
mkdir -p feeds/packages/utils/dockerd/patches
cp -f $GITHUB_WORKSPACE/scripts/001-dockerd-skip-missing-nested-executables.patch \
	feeds/packages/utils/dockerd/patches/001-dockerd-skip-missing-nested-executables.patch

# 注：ImmortalWrt 25.12 的 dockerd 本来就不 select cgroupfs-mount，
# feeds 里也没有 cgroupfs-mount 包，因此 LEDE 版的
# cgroupfs-mount.init 替换和 008-dockerd-cgroupfs.patch 在这里不需要。
