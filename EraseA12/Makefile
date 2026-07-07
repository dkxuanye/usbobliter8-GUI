.PHONY: project build clean test

project:
	xcodegen generate -s project.yml -o EraseA12.xcodeproj

build: project
	xcodebuild -project EraseA12.xcodeproj -scheme EraseA12 -configuration Release build

test: project
	xcodebuild -project EraseA12.xcodeproj -scheme EraseA12Tests -configuration Debug test

clean:
	rm -rf build EraseA12.xcodeproj DerivedData
