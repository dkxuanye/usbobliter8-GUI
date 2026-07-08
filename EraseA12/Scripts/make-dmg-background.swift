#!/usr/bin/env swift
//
// make-dmg-background.swift
//
// 用 Core Graphics 绘制 EraseA12 DMG 背景图：
//   - 暗色渐变底板
//   - 标题"安装 EraseA12"
//   - 副标题提示用户把 EraseA12.app 拖到 Applications 文件夹
//   - 左侧应用图标占位（圆角矩形 + 简化设备 + 蓝色光带）
//   - 中间粗箭头 + "拖动" 文字
//   - 右侧 Applications 文件夹占位
//   - 底部首次打开提示
//
// 用法：swift Scripts/make-dmg-background.swift [输出PNG路径]
//   默认输出到 Scripts/dmg-background.png
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - 尺寸常量

let canvasWidth: CGFloat = 540
let canvasHeight: CGFloat = 360

let iconBoxSide: CGFloat = 128
let leftIconCenterX: CGFloat = 130
let rightIconCenterX: CGFloat = 410
let iconCenterY: CGFloat = 200

let outputPath: String
if CommandLine.arguments.count > 1 {
    outputPath = CommandLine.arguments[1]
} else {
    let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    outputPath = scriptDir.appendingPathComponent("dmg-background.png").path
}

// MARK: - 辅助绘制

func makeAttributedString(
    _ text: String,
    fontSize: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = .white
) -> NSAttributedString {
    let font: NSFont
    if weight == .bold {
        font = NSFont.boldSystemFont(ofSize: fontSize)
    } else if weight == .medium {
        font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
    } else {
        font = NSFont.systemFont(ofSize: fontSize)
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail
    return NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    )
}

func drawAttributedCentered(
    _ attributed: NSAttributedString,
    in rect: NSRect,
    context: CGContext
) {
    context.saveGState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    attributed.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    context.restoreGState()
}

// MARK: - 图标绘制

func drawAppIconPlaceholder(in rect: NSRect, context: CGContext) {
    // 圆角矩形底板
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22)
    // 深石墨渐变
    let bgGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1.0),
            NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        ]
    )!
    bgGradient.draw(in: bgPath, angle: -90)

    // 设备轮廓（简化版）
    let deviceRect = NSRect(
        x: rect.minX + rect.width * 0.28,
        y: rect.minY + rect.height * 0.22,
        width: rect.width * 0.44,
        height: rect.height * 0.62
    )
    let devicePath = NSBezierPath(roundedRect: deviceRect, xRadius: 8, yRadius: 8)
    NSColor(calibratedWhite: 0.92, alpha: 1.0).setStroke()
    devicePath.lineWidth = 2.2
    devicePath.stroke()

    // 蓝色光带（横向清除感）
    let beamRect = NSRect(
        x: deviceRect.minX - 6,
        y: deviceRect.midY - 6,
        width: deviceRect.width + 12,
        height: 12
    )
    let beamPath = NSBezierPath(roundedRect: beamRect, xRadius: 6, yRadius: 6)
    NSColor(calibratedRed: 0.30, green: 0.62, blue: 1.0, alpha: 0.95).setFill()
    beamPath.fill()

    // 小红点
    let dotRect = NSRect(
        x: rect.maxX - 18,
        y: rect.maxY - 18,
        width: 8,
        height: 8
    )
    NSColor(calibratedRed: 0.95, green: 0.30, blue: 0.30, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: dotRect).fill()
}

func drawApplicationsIcon(in rect: NSRect, context: CGContext) {
    // 文件夹主体
    let bodyRect = NSRect(
        x: rect.minX + 6,
        y: rect.minY + 14,
        width: rect.width - 12,
        height: rect.height - 26
    )
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 10, yRadius: 10)
    let bodyGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.95, alpha: 1.0),
            NSColor(calibratedRed: 0.55, green: 0.65, blue: 0.85, alpha: 1.0)
        ]
    )!
    bodyGradient.draw(in: bodyPath, angle: -90)

    // 文件夹顶部标签
    let tabRect = NSRect(
        x: rect.minX + 14,
        y: rect.maxY - 26,
        width: 60,
        height: 14
    )
    let tabPath = NSBezierPath(roundedRect: tabRect, xRadius: 4, yRadius: 4)
    NSColor(calibratedRed: 0.55, green: 0.65, blue: 0.85, alpha: 1.0).setFill()
    tabPath.fill()

    // 中心加一个简单的"App"图标暗示
    let appIconRect = NSRect(
        x: bodyRect.midX - 22,
        y: bodyRect.midY - 22,
        width: 44,
        height: 44
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.85).setStroke()
    NSBezierPath(roundedRect: appIconRect, xRadius: 8, yRadius: 8).stroke()
    let title = makeAttributedString("A", fontSize: 26, weight: .bold, color: NSColor(calibratedRed: 0.30, green: 0.45, blue: 0.75, alpha: 1.0))
    drawAttributedCentered(title, in: appIconRect, context: context)
}

// MARK: - 箭头

func drawArrow(from start: NSPoint, to end: NSPoint, context: CGContext) {
    context.saveGState()
    context.setStrokeColor(NSColor(calibratedWhite: 0.95, alpha: 1.0).cgColor)
    context.setFillColor(NSColor(calibratedWhite: 0.95, alpha: 1.0).cgColor)
    context.setLineWidth(8)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // 主线
    context.move(to: start)
    context.addLine(to: end)
    context.strokePath()

    // 箭头头部（三角）
    let angle = atan2(end.y - start.y, end.x - start.x)
    let headLength: CGFloat = 18
    let headAngle: CGFloat = .pi / 7
    let p1 = NSPoint(
        x: end.x - headLength * cos(angle - headAngle),
        y: end.y - headLength * sin(angle - headAngle)
    )
    let p2 = NSPoint(
        x: end.x - headLength * cos(angle + headAngle),
        y: end.y - headLength * sin(angle + headAngle)
    )
    context.move(to: end)
    context.addLine(to: p1)
    context.addLine(to: p2)
    context.closePath()
    context.fillPath()
    context.restoreGState()
}

// MARK: - 主绘制流程

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasWidth),
    pixelsHigh: Int(canvasHeight),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
) else {
    fputs("错误：无法创建位图\n", stderr)
    exit(1)
}

bitmap.size = NSSize(width: canvasWidth, height: canvasHeight)

let cgContext = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)

// 1. 暗色渐变背景
let bgPath = NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
let bgGradient = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.14, alpha: 1.0),
        NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
    ]
)!
bgGradient.draw(in: bgPath, angle: -90)

// 2. 标题
let title = makeAttributedString("安装 EraseA12", fontSize: 28, weight: .bold, color: .white)
drawAttributedCentered(title, in: NSRect(x: 0, y: canvasHeight - 64, width: canvasWidth, height: 36), context: cgContext)

// 3. 副标题
let subtitle = makeAttributedString(
    "将 EraseA12.app 拖动到右侧 Applications 文件夹中",
    fontSize: 14,
    color: NSColor(calibratedWhite: 0.78, alpha: 1.0)
)
drawAttributedCentered(subtitle, in: NSRect(x: 0, y: canvasHeight - 96, width: canvasWidth, height: 22), context: cgContext)

// 4. 左侧应用图标占位
let leftRect = NSRect(
    x: leftIconCenterX - iconBoxSide / 2,
    y: iconCenterY - iconBoxSide / 2,
    width: iconBoxSide,
    height: iconBoxSide
)
drawAppIconPlaceholder(in: leftRect, context: cgContext)

// 5. 右侧 Applications 文件夹占位
let rightRect = NSRect(
    x: rightIconCenterX - iconBoxSide / 2,
    y: iconCenterY - iconBoxSide / 2,
    width: iconBoxSide,
    height: iconBoxSide
)
drawApplicationsIcon(in: rightRect, context: cgContext)

// 6. 中间箭头
drawArrow(
    from: NSPoint(x: leftRect.maxX + 8, y: iconCenterY),
    to: NSPoint(x: rightRect.minX - 8, y: iconCenterY),
    context: cgContext
)

// 7. "拖动"小字
let dragLabel = makeAttributedString(
    "拖动",
    fontSize: 13,
    weight: .medium,
    color: NSColor(calibratedWhite: 0.90, alpha: 1.0)
)
drawAttributedCentered(
    dragLabel,
    in: NSRect(x: leftRect.maxX, y: iconCenterY - 36, width: rightRect.minX - leftRect.maxX, height: 22),
    context: cgContext
)

// 8. 底部首次打开提示
let footer = makeAttributedString(
    "首次打开请参考 DMG 内《打开方式.txt》",
    fontSize: 11,
    color: NSColor(calibratedWhite: 0.55, alpha: 1.0)
)
drawAttributedCentered(footer, in: NSRect(x: 0, y: 22, width: canvasWidth, height: 20), context: cgContext)

NSGraphicsContext.restoreGraphicsState()

// MARK: - 输出 PNG

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("错误：无法生成 PNG 数据\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("已生成背景图: \(outputPath) (\(canvasWidth)x\(canvasHeight), \(pngData.count) bytes)")
} catch {
    fputs("错误：写入失败 \(error.localizedDescription)\n", stderr)
    exit(1)
}