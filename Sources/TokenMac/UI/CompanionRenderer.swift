import AppKit

/// 캐릭터 렌더러 — 코드 드로잉(Core Graphics). PNG 스프라이트 없음.
/// Phase 1 은 기본 캐릭터 Mochi(크림 태비 고양이) 1종. 로스터 확장은 Phase 2+.
/// 좌표계는 64x64 y-down (프리뷰 JS 엔진과 동일), 표시 크기로 스케일.
enum CompanionRenderer {
    private static let SZ: CGFloat = 64

    // Mochi(크림) 팔레트
    private static let o  = hex(0x6f6760), C = hex(0xF7EFE1), S = hex(0xEADCC4)
    private static let H  = hex(0xFFFFFF), ear = hex(0xF0B7B3), blush = hex(0xF6CCC6)
    private static let E  = hex(0x6a615c), B = hex(0x8FC0F2), Bd = hex(0xC2E0FF)
    private static let A  = hex(0xF4C863), stripe = hex(0xE3CFA9)

    static func image(size: CGFloat, state: CompanionStateKind, level: Int, time: TimeInterval) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.interpolationQuality = .high
            let s = size / SZ
            ctx.translateBy(x: 0, y: size)      // y-down 64좌표로
            ctx.scaleBy(x: s, y: -s)
            ctx.setLineJoin(.round)
            draw(ctx, state: state, t: time)
            ctx.restoreGState()
        }
        img.unlockFocus()
        return img
    }

    // MARK: 엔진

    private static func draw(_ ctx: CGContext, state: CompanionStateKind, t T: TimeInterval) {
        if state == .egg { drawEgg(ctx, T); return }

        var breathe = 0.0, bounce = 0.0, sway = sin(T * 1.2) * 3, tw = 0.0, loaf = 0.0
        var eye = "open"; var earUp = false, droop = false
        var sweat = false, z = false, sparkle = false, charm = false

        switch state {
        case .idle:
            breathe = sin(T * 1.5); eye = sin(T * 0.95) > 0.95 ? "blink" : "open"
            tw = sin(T * 0.7) * 0.8; sway = sin(T * 1.0) * 3
        case .working:
            bounce = abs(sin(T * 3.2)) * 1.6; breathe = sin(T * 3.2) * 0.5
            tw = sin(T * 5.5) * 1.0; sway = sin(T * 3.6) * 4
        case .focus:
            earUp = true; bounce = abs(sin(T * 6)) * 0.9; breathe = sin(T * 6) * 0.4
            sway = sin(T * 5) * 4.5; charm = sin(T * 6) > 0
        case .tired:
            droop = true; eye = "half"; sweat = true; loaf = 2.4
            breathe = sin(T * 0.85) * 0.7; sway = sin(T * 0.65) * 2
        case .sleep:
            eye = "closed"; z = true; loaf = 5; breathe = sin(T * 1.0) * 1.1; sway = sin(T * 0.5) * 1.4
        case .levelUp:
            earUp = true; eye = "wide"; sparkle = true
            bounce = abs(sin(T * 3.8)) * 3.2; sway = sin(T * 4.6) * 4.5
        case .egg: return
        }

        ctx.translateBy(x: 0, y: -bounce)
        let cx = 32.0, cy = 35 + loaf * 0.5, rx = 21 + loaf, ry = 17 - loaf * 0.6 + breathe

        drawTail(ctx, cx, cy, rx, ry, sway, droop)
        drawBody(ctx, cx, cy, rx, ry, earUp, droop, tw)
        drawStripes(ctx, cx, cy, rx, ry)
        drawFace(ctx, cx, cy, rx, ry, eye)
        fillEll(ctx, cx, cy + ry * 0.62, 2.4, 2.4, charm ? Bd : B); strokeEll(ctx, cx, cy + ry * 0.62, 2.4, 2.4, o, 1)
        if sweat { fillEll(ctx, cx + rx * 0.62, cy - ry * 0.44, 1.8, 2.6, A) }
        if z { drawZ(ctx, cx + rx * 0.6, cy - ry - 3) }
        if sparkle { drawSparkles(ctx, T) }
    }

    private static func drawBody(_ ctx: CGContext, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double,
                                 _ up: Bool, _ droop: Bool, _ tw: Double) {
        // 1) 어두운 통합 실루엣(귀+몸 부풀려)
        fillPath(ctx, earPath(cx, cy, rx, ry, -1, up, droop, tw, 1.8), o)
        fillPath(ctx, earPath(cx, cy, rx, ry,  1, up, droop, tw, 1.8), o)
        fillEll(ctx, cx, cy, rx + 1.7, ry + 1.7, o)
        // 2) 몸
        fillEll(ctx, cx, cy, rx, ry, C)
        // 3) 바닥 그림자
        ctx.saveGState()
        ctx.addPath(ellPath(cx, cy, rx, ry)); ctx.clip()
        ctx.setAlpha(0.5); ctx.setFillColor(S); ctx.fill(CGRect(x: 0, y: cy + ry * 0.5, width: SZ, height: SZ))
        ctx.restoreGState()
        // 4) 뾰족 귀(통합) + 안쪽 핑크
        fillPath(ctx, earPath(cx, cy, rx, ry, -1, up, droop, tw, 0), C)
        fillPath(ctx, earPath(cx, cy, rx, ry,  1, up, droop, tw, 0), C)
        fillPath(ctx, innerEar(cx, cy, rx, ry, -1, up, droop, tw), ear)
        fillPath(ctx, innerEar(cx, cy, rx, ry,  1, up, droop, tw), ear)
    }

    private static func earPath(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double,
                                _ side: Double, _ up: Bool, _ droop: Bool, _ tw: Double, _ grow: Double) -> CGPath {
        let ux = cx + side * (rx * 0.64 + grow * 0.4), uy = cy - ry * 0.48
        let ix = cx + side * rx * 0.14, iy = cy - ry * 0.84
        var tx = cx + side * (rx * 0.50) + tw, ty = cy - ry * (up ? 1.46 : 1.32) - grow
        if droop { tx = cx + side * (rx * 0.92) + grow * 0.5; ty = cy - ry * 0.58 }
        let p = CGMutablePath()
        p.move(to: CGPoint(x: ux, y: uy))
        p.addQuadCurve(to: CGPoint(x: tx, y: ty), control: CGPoint(x: cx + side * (rx * 0.70 + grow * 0.4), y: (uy + ty) / 2))
        p.addQuadCurve(to: CGPoint(x: ix, y: iy), control: CGPoint(x: cx + side * rx * 0.30, y: (ty + iy) / 2))
        p.closeSubpath()
        return p
    }

    private static func innerEar(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double,
                                 _ side: Double, _ up: Bool, _ droop: Bool, _ tw: Double) -> CGPath {
        let ix = cx + side * rx * 0.30, iy = cy - ry * 0.62
        var tx = cx + side * rx * 0.46 + tw, ty = cy - ry * (up ? 1.20 : 1.08)
        if droop { tx = cx + side * rx * 0.74; ty = cy - ry * 0.52 }
        let bx = cx + side * rx * 0.24, by = cy - ry * 0.78
        let p = CGMutablePath()
        p.move(to: CGPoint(x: ix, y: iy))
        p.addQuadCurve(to: CGPoint(x: tx, y: ty), control: CGPoint(x: cx + side * rx * 0.5, y: (iy + ty) / 2))
        p.addLine(to: CGPoint(x: bx, y: by)); p.closeSubpath()
        return p
    }

    private static func drawStripes(_ ctx: CGContext, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) {
        let y0 = cy - ry * 0.52, len = ry * 0.22
        for dx in [-rx * 0.26, 0, rx * 0.26] {
            strokeLine(ctx, [CGPoint(x: cx + dx, y: y0), CGPoint(x: cx + dx * 1.18, y: y0 + len)], stripe, 2.2)
        }
    }

    private static func drawTail(_ ctx: CGContext, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double,
                                 _ sway: Double, _ droop: Bool) {
        let bx = cx + rx * 0.72, by = cy + ry * 0.42, c0 = cx + rx * 1.2
        let tx = cx + rx * (droop ? 0.96 : 1.12) + sway * 0.5, ty = (droop ? cy + ry * 0.62 : cy - ry * 0.42) + sway * 0.7
        let q = CGMutablePath(); q.move(to: CGPoint(x: bx, y: by))
        q.addQuadCurve(to: CGPoint(x: tx, y: ty), control: CGPoint(x: c0, y: cy))
        strokePath(ctx, q, o, 6); strokePath(ctx, q, C, 3.4)
        // 태비 꼬리 줄
        for tparam in [0.5, 0.78] {
            let u = 1 - tparam
            let qx = u * u * bx + 2 * u * tparam * c0 + tparam * tparam * tx
            let qy = u * u * by + 2 * u * tparam * cy + tparam * tparam * ty
            strokeLine(ctx, [CGPoint(x: qx - 2.2, y: qy), CGPoint(x: qx + 2.2, y: qy)], stripe, 2)
        }
    }

    private static func drawFace(_ ctx: CGContext, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ eye: String) {
        let fy = cy + ry * 0.12, eyeDX = rx * 0.40
        ctx.saveGState(); ctx.setAlpha(0.4)
        fillEll(ctx, cx - rx * 0.6, fy + 3, 3.2, 2.1, blush); fillEll(ctx, cx + rx * 0.6, fy + 3, 3.2, 2.1, blush)
        ctx.restoreGState()
        // 수염
        for sd in [-1.0, 1.0] {
            strokeLine(ctx, [CGPoint(x: cx + sd * rx * 0.46, y: fy + 2), CGPoint(x: cx + sd * rx * 0.82, y: fy + 1)], S, 1)
            strokeLine(ctx, [CGPoint(x: cx + sd * rx * 0.46, y: fy + 4), CGPoint(x: cx + sd * rx * 0.82, y: fy + 5)], S, 1)
        }
        drawEye(ctx, cx - eyeDX, fy, eye); drawEye(ctx, cx + eyeDX, fy, eye)
        // 코
        let n = CGMutablePath()
        n.move(to: CGPoint(x: cx - 1.7, y: fy + 4)); n.addLine(to: CGPoint(x: cx + 1.7, y: fy + 4))
        n.addLine(to: CGPoint(x: cx, y: fy + 5.8)); n.closeSubpath()
        fillPath(ctx, n, ear)
        // 미소
        if eye != "closed" {
            let m = CGMutablePath(); m.move(to: CGPoint(x: cx - 2.0, y: fy + 7))
            m.addQuadCurve(to: CGPoint(x: cx + 2.0, y: fy + 7), control: CGPoint(x: cx, y: fy + 8.5))
            strokePath(ctx, m, o, 1.2)
        }
    }

    private static func drawEye(_ ctx: CGContext, _ x: Double, _ y: Double, _ mode: String) {
        if mode == "closed" || mode == "half" {
            let dip = mode == "closed" ? 2.6 : 1.2
            let p = CGMutablePath(); p.move(to: CGPoint(x: x - 2.8, y: y))
            p.addQuadCurve(to: CGPoint(x: x + 2.8, y: y), control: CGPoint(x: x, y: y + dip))
            strokePath(ctx, p, E, 2.0); return
        }
        let ery = mode == "blink" ? 0.6 : mode == "wide" ? 3.9 : mode == "narrow" ? 2.4 : 3.2
        fillEll(ctx, x, y, 2.6, ery, E)
        if mode != "blink" {
            fillEll(ctx, x - 0.9, y - ery * 0.42, 1.2, 1.4, H)
            fillEll(ctx, x + 0.9, y + ery * 0.34, 0.55, 0.62, H)
        }
    }

    private static func drawZ(_ ctx: CGContext, _ x: Double, _ y: Double) {
        for (s, off) in [(4.4, 0.0), (3.0, 6.0)] {
            strokeLine(ctx, [CGPoint(x: x + off, y: y + off), CGPoint(x: x + off + s, y: y + off),
                             CGPoint(x: x + off, y: y + off + s), CGPoint(x: x + off + s, y: y + off + s)], o, 1.6)
        }
    }

    private static func drawSparkles(_ ctx: CGContext, _ T: TimeInterval) {
        for (x, y, ph) in [(14.0, 12.0, 0.0), (50.0, 16.0, 1.4), (34.0, 7.0, 2.6)] {
            let s = 1.4 + abs(sin(T * 4 + ph)) * 1.8
            strokeLine(ctx, [CGPoint(x: x - s, y: y), CGPoint(x: x + s, y: y)], A, 1.5)
            strokeLine(ctx, [CGPoint(x: x, y: y - s), CGPoint(x: x, y: y + s)], A, 1.5)
        }
    }

    private static func drawEgg(_ ctx: CGContext, _ T: TimeInterval) {
        let cx = 32.0
        ctx.saveGState(); ctx.translateBy(x: cx, y: 40); ctx.rotate(by: sin(T * 2.6) * 0.06); ctx.translateBy(x: -cx, y: -40)
        let outer = CGMutablePath(); outer.move(to: CGPoint(x: cx, y: 18))
        outer.addCurve(to: CGPoint(x: cx, y: 55), control1: CGPoint(x: cx + 16, y: 21), control2: CGPoint(x: cx + 17, y: 55))
        outer.addCurve(to: CGPoint(x: cx, y: 18), control1: CGPoint(x: cx - 17, y: 55), control2: CGPoint(x: cx - 16, y: 21))
        fillPath(ctx, outer, o)
        let inner = CGMutablePath(); inner.move(to: CGPoint(x: cx, y: 19.6))
        inner.addCurve(to: CGPoint(x: cx, y: 53.4), control1: CGPoint(x: cx + 14.4, y: 22.4), control2: CGPoint(x: cx + 15.3, y: 53.4))
        inner.addCurve(to: CGPoint(x: cx, y: 19.6), control1: CGPoint(x: cx - 14.4, y: 53.4), control2: CGPoint(x: cx - 15.3, y: 22.4))
        fillPath(ctx, inner, C)
        fillEll(ctx, cx - 6, 28, 2, 2.8, H)
        let on = sin(T * 3.4) > 0, r = 2.8 + sin(T * 3.4) * 0.8
        fillEll(ctx, cx, 40, r, r, on ? Bd : B)
        ctx.restoreGState()
    }

    // MARK: 저수준 헬퍼

    private static func hex(_ v: Int) -> CGColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                blue: CGFloat(v & 0xff) / 255, alpha: 1).cgColor
    }
    private static func ellPath(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> CGPath {
        CGPath(ellipseIn: CGRect(x: cx - max(0.4, rx), y: cy - max(0.4, ry), width: 2 * max(0.4, rx), height: 2 * max(0.4, ry)), transform: nil)
    }
    private static func fillEll(_ ctx: CGContext, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: CGColor) {
        ctx.setFillColor(c); ctx.addPath(ellPath(cx, cy, rx, ry)); ctx.fillPath()
    }
    private static func strokeEll(_ ctx: CGContext, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: CGColor, _ w: Double) {
        ctx.setStrokeColor(c); ctx.setLineWidth(w); ctx.addPath(ellPath(cx, cy, rx, ry)); ctx.strokePath()
    }
    private static func fillPath(_ ctx: CGContext, _ p: CGPath, _ c: CGColor) {
        ctx.setFillColor(c); ctx.addPath(p); ctx.fillPath()
    }
    private static func strokePath(_ ctx: CGContext, _ p: CGPath, _ c: CGColor, _ w: Double) {
        ctx.setStrokeColor(c); ctx.setLineWidth(w); ctx.setLineCap(.round); ctx.addPath(p); ctx.strokePath()
    }
    private static func strokeLine(_ ctx: CGContext, _ pts: [CGPoint], _ c: CGColor, _ w: Double) {
        let p = CGMutablePath(); p.addLines(between: pts); strokePath(ctx, p, c, w)
    }
}
