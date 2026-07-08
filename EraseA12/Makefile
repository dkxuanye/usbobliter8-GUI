.PHONY: project build test clean release dmg

project:
	xcodegen generate -s project.yml -o EraseA12.xcodeproj

build: project
	xcodebuild -project EraseA12.xcodeproj -scheme EraseA12 -configuration Release build

test: project
	xcodebuild -project EraseA12.xcodeproj -scheme EraseA12Tests -configuration Debug test

clean:
	rm -rf build EraseA12.xcodeproj DerivedData

# 一键发布：clean Release + ad-hoc 签名 + DMG 打包
# 产物：仓库根目录 EraseA12-<version>.dmg
# GUI 环境：Finder 自动配置窗口布局生成 .DS_Store
# 无 GUI 环境：加 SKIP_DMG_FINDER_LAYOUT=1 跳过 Finder 步骤
release: project
	./Scripts/package-dmg.sh

# 仅打 DMG：依赖 build 已完成
dmg: project
	./Scripts/package-dmg.sh