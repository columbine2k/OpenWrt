#!/bin/bash

# ============================================================
# diy-script：编译前对 OpenWrt/LEDE 源码做定制
#
# 约定：
#   - 对上游文件的具体修改一律做成补丁放在 patches/*.patch，
#     本脚本统一用 git apply 应用（见下方“统一应用补丁”）
#   - 只有批量/动态改动保留为脚本：插件克隆、Makefile 批量重写、
#     编译日期版本号、主题默认值清理
# ============================================================

# 移除要替换的包
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf feeds/luci/applications/luci-app-netdata

# 可选开关（默认关闭，需要时取消注释）
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 添加额外插件
git clone --depth=1 https://github.com/esirplayground/luci-app-poweroff package/luci-app-poweroff
git clone --depth=1 https://github.com/Jason6111/luci-app-netdata package/luci-app-netdata
git_sparse_clone main https://github.com/Lienol/openwrt-package luci-app-filebrowser
# git_sparse_clone master https://github.com/syb999/openwrt-19.07.1 package/network/services/msd_lite

# Themes
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config

# 在线用户
git_sparse_clone main https://github.com/haiibo/packages luci-app-onliner
chmod 755 package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh

# 修改版本为编译日期（动态内容，不能写成静态补丁）
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version}/g" package/lean/default-settings/files/zzz-default-settings

# 批量 Makefile 重写（面向多个动态克隆的包，保留脚本方式）
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# 取消主题默认设置（批量处理所有主题，保留脚本方式）
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

./scripts/feeds update -a
./scripts/feeds install -a

# —— 统一应用补丁（patches/*.patch，路径相对 openwrt 根目录）——
# 已应用过的补丁会被 git apply --reverse --check 识别并跳过，重复构建安全；
# 真正冲突的补丁会直接报错退出，避免“悄悄漏改”
_patch_dir="$GITHUB_WORKSPACE/patches"
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

# cgroupfs-mount 开机脚本整体替换（完整文件，直接复制而非补丁）
_cgroupfs_init="feeds/packages/utils/cgroupfs-mount/files/cgroupfs-mount.init"
if [ -f "$_cgroupfs_init" ]; then
	cp -f "$_patch_dir/cgroupfs-mount.init" "$_cgroupfs_init"
fi

# hostapd / dockerd 的补丁走 OpenWrt 包自身的 patches/ 机制
# （构建对应包时自动应用），因此单独复制而不是在上面的循环里打
cp -f $GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch
mkdir -p feeds/packages/utils/dockerd/patches
cp -f $GITHUB_WORKSPACE/scripts/001-dockerd-skip-missing-nested-executables.patch \
	feeds/packages/utils/dockerd/patches/001-dockerd-skip-missing-nested-executables.patch
