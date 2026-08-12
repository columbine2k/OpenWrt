#!/bin/bash

# 修改默认IP
sed -i 's/192.168.1.1/192.168.0.200/g' package/base-files/files/bin/config_generate

# 修改 uhttpd 监听端口（HTTP 1000 / HTTPS 1001），把 80/443 让给 Nginx Proxy Manager
sed -i 's/0\.0\.0\.0:80/0.0.0.0:1000/g; s/\[::\]:80/[::]:1000/g; s/0\.0\.0\.0:443/0.0.0.0:1001/g; s/\[::\]:443/[::]:1001/g' package/network/services/uhttpd/files/uhttpd.config

# 更改默认 Shell 为 zsh
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD 免登录
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 移除要替换的包
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf feeds/luci/applications/luci-app-netdata

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
sed -i '$i uci set nlbwmon.@nlbwmon[0].refresh_interval=2s' package/lean/default-settings/files/zzz-default-settings
sed -i '$i uci commit nlbwmon' package/lean/default-settings/files/zzz-default-settings
chmod 755 package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh

# x86 型号只显示 CPU 型号
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# 修改本地时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改版本为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version}/g" package/lean/default-settings/files/zzz-default-settings

# 修复 hostapd 报错
cp -f $GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch

# 修复 armv8 设备 xfsprogs 报错
sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile

# 修改 Makefile
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# 为 Docker 启用完整 cgroup 支持，消除 docker info 中的 WARNING
# （No swap/cpu cfs/cpu shares/io.weight/io.max support）
for _kcfg in target/linux/rockchip/armv8/config-*; do
	[ -f "$_kcfg" ] || continue
	for _opt in CONFIG_CGROUPS CONFIG_CGROUP_SCHED CONFIG_FAIR_GROUP_SCHED \
	            CONFIG_CFS_BANDWIDTH CONFIG_MEMCG CONFIG_MEMCG_SWAP CONFIG_BLK_CGROUP; do
		grep -q "^${_opt}=" "$_kcfg" 2>/dev/null || echo "${_opt}=y" >> "$_kcfg"
	done
done

# 取消主题默认设置
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

./scripts/feeds update -a
./scripts/feeds install -a

# 修复 samba4-server 与 autosamba 的文件冲突：
# 两者都会安装 /etc/hotplug.d/block/20-smb，导致 package/install 报
# check_data_file_clashes 失败；这里去掉 samba4-server 自带的 hotplug 脚本，
# 保留 autosamba 的
_samba4_makefile="feeds/packages/net/samba4/Makefile"
[ -f "$_samba4_makefile" ] && sed -i '/etc\/hotplug\.d\/block/d' "$_samba4_makefile"

# 新版 Dockerman（ucode/JS 版）默认把菜单挂在“服务”下，标题为 Dockerman JS；
# 这里把它挪回顶层“Docker”栏目，还原 24.02.19 时代的布局
_dockerman_menu="feeds/luci/applications/luci-app-dockerman/root/usr/share/luci/menu.d/luci-app-dockerman.json"
[ -f "$_dockerman_menu" ] && sed -i \
	-e 's#admin/services/dockerman#admin/docker#g' \
	-e 's#"Dockerman JS"#"Docker"#g' \
	"$_dockerman_menu"
