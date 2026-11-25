// Pixel-Engine + alle Animationen von ClaudePet.
import SwiftUI

// MARK: - Raster

let px: CGFloat = 5
let gridW = 40, gridH = 30          // Fenster = 200 x 150 pt
let bodyX = 12, bodyY = 20          // Körper-Ursprung im Raster

typealias Sp = [String]

func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

let pal: [Character: Color] = [
    "#": rgb(0.85, 0.47, 0.34),   // Claude-Orange
    "q": rgb(0.70, 0.66, 0.84),   // durchgefroren
    "k": rgb(0.10, 0.09, 0.08),
    "w": rgb(0.97, 0.97, 0.95),
    "m": rgb(0.93, 0.87, 0.76),
    "c": rgb(0.40, 0.24, 0.14),
    "b": rgb(0.58, 0.38, 0.22),
    "r": rgb(0.88, 0.27, 0.27),
    "p": rgb(0.98, 0.56, 0.72),
    "y": rgb(0.99, 0.83, 0.27),
    "o": rgb(1.00, 0.62, 0.18),
    "g": rgb(0.38, 0.74, 0.38),
    "d": rgb(0.20, 0.47, 0.24),
    "u": rgb(0.32, 0.54, 0.93),
    "l": rgb(0.64, 0.86, 1.00),
    "s": rgb(0.64, 0.65, 0.68),
    "a": rgb(0.33, 0.34, 0.37),
    "v": rgb(0.60, 0.47, 0.86),
    "t": rgb(0.95, 0.76, 0.46),
]

// MARK: - Körper

enum Eyes { case open, closed, happy, left, right, up, down, wide, wink, dizzy, none }
enum Arm { case side, up, out, down, none }
enum Legs { case stand, step, sit }
enum Mouth { case none, o, smile, line, small }

struct BodyOpt {
    var eyes = Eyes.open
    var mouth = Mouth.none
    var armL = Arm.side
    var armR = Arm.side
    var legs = Legs.stand
    var tint: Character = "#"
}

func eyeCells(_ e: Eyes) -> [(Int, Int)] {
    switch e {
    case .open: return [(4, 1), (4, 2), (11, 1), (11, 2)]
    case .closed: return [(3, 2), (4, 2), (11, 2), (12, 2)]
    case .happy: return [(3, 2), (4, 1), (5, 2), (10, 2), (11, 1), (12, 2)]
    case .left: return [(3, 1), (3, 2), (10, 1), (10, 2)]
    case .right: return [(5, 1), (5, 2), (12, 1), (12, 2)]
    case .up: return [(4, 0), (4, 1), (11, 0), (11, 1)]
    case .down: return [(4, 2), (4, 3), (11, 2), (11, 3)]
    case .wide: return [(4, 1), (5, 1), (4, 2), (5, 2), (10, 1), (11, 1), (10, 2), (11, 2)]
    case .wink: return [(4, 1), (4, 2), (10, 2), (11, 2), (12, 2)]
    case .dizzy: return [(3, 0), (5, 0), (4, 1), (3, 2), (5, 2), (10, 0), (12, 0), (11, 1), (10, 2), (12, 2)]
    case .none: return []
    }
}

func mouthCells(_ m: Mouth) -> [(Int, Int)] {
    switch m {
    case .none: return []
    case .o: return [(7, 4), (8, 4), (7, 5), (8, 5)]
    case .smile: return [(6, 4), (7, 5), (8, 5), (9, 4)]
    case .line: return [(6, 5), (7, 5), (8, 5), (9, 5)]
    case .small: return [(7, 4), (8, 4)]
    }
}

func armCells(_ a: Arm, right: Bool) -> [(Int, Int)] {
    let c: [(Int, Int)]
    switch a {
    case .side: c = [(0, 3), (1, 3), (0, 4), (1, 4)]
    case .up: c = [(1, 3), (1, 4), (0, 3), (0, 2), (-1, 1), (-1, 0)]
    case .out: c = [(1, 3), (1, 4), (0, 3), (0, 4), (-1, 3), (-2, 3)]
    case .down: c = [(1, 4), (1, 5), (0, 5), (0, 6)]
    case .none: c = []
    }
    return right ? c.map { (15 - $0.0, $0.1) } : c
}

// MARK: - Frame

struct Frame {
    var body = BodyOpt()
    var dx: CGFloat = 0, dy: CGFloat = 0
    var rot: Double = 0
    var sx: CGFloat = 1, sy: CGFloat = 1
    var flip = false
    var heldBack: [(Sp, Int, Int)] = []   // bewegt sich mit Körper, dahinter
    var held: [(Sp, Int, Int)] = []       // bewegt sich mit Körper, davor
    var back: [(Sp, Int, Int)] = []       // fest in der Szene, dahinter
    var front: [(Sp, Int, Int)] = []      // fest in der Szene, davor
}

func F(_ build: (inout Frame) -> Void) -> Frame { var f = Frame(); build(&f); return f }

func blit(_ ctx: GraphicsContext, _ s: Sp, _ x: Int, _ y: Int) {
    for (j, row) in s.enumerated() {
        for (i, ch) in row.enumerated() {
            guard let c = pal[ch] else { continue }
            let r = CGRect(x: CGFloat(x + i) * px, y: CGFloat(y + j) * px, width: px + 0.4, height: px + 0.4)
            ctx.fill(Path(r), with: .color(c))
        }
    }
}

func fillCells(_ ctx: GraphicsContext, _ cells: [(Int, Int)], _ ch: Character) {
    guard let c = pal[ch] else { return }
    for (x, y) in cells {
        ctx.fill(Path(CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: px + 0.4, height: px + 0.4)), with: .color(c))
    }
}

func drawBody(_ ctx: GraphicsContext, _ o: BodyOpt) {
    var cells: [(Int, Int)] = []
    for y in 0..<7 { for x in 2..<14 { cells.append((x, y)) } }
    cells += armCells(o.armL, right: false) + armCells(o.armR, right: true)
    switch o.legs {
    case .stand: for x in [3, 5, 10, 12] { cells += [(x, 7), (x, 8)] }
    case .step: for x in [4, 6, 9, 11] { cells += [(x, 7), (x, 8)] }
    case .sit: break
    }
    fillCells(ctx, cells, o.tint)
    fillCells(ctx, eyeCells(o.eyes) + mouthCells(o.mouth), "k")
}

func drawFrame(_ ctx: GraphicsContext, _ f: Frame) {
    var scene = ctx
    scene.translateBy(x: CGFloat(bodyX) * px, y: CGFloat(bodyY) * px)
    for (s, x, y) in f.back { blit(scene, s, x, y) }

    // Schatten wird kleiner, je höher er springt
    let lift = max(0, -f.dy)
    let w = max(20, (16 * px - lift * 0.8) * f.sx)
    scene.fill(Path(ellipseIn: CGRect(x: 8 * px - w / 2 + f.dx, y: 9 * px - 3, width: w, height: 5)),
               with: .color(.black.opacity(0.22)))

    var b = scene
    let sit: CGFloat = f.body.legs == .sit ? 2 * px : 0
    b.translateBy(x: f.dx + 8 * px, y: f.dy + sit + 9 * px)   // Füße unten mittig
    b.scaleBy(x: f.sx * (f.flip ? -1 : 1), y: f.sy)
    b.translateBy(x: 0, y: -4.5 * px)                          // Drehpunkt Körpermitte
    b.rotate(by: .degrees(f.rot))
    b.translateBy(x: -8 * px, y: -4.5 * px)
    for (s, x, y) in f.heldBack { blit(b, s, x, y) }
    drawBody(b, f.body)
    for (s, x, y) in f.held { blit(b, s, x, y) }
    for (s, x, y) in f.front { blit(scene, s, x, y) }
}

// MARK: - Helfer

func ph(_ t: Int, _ n: Int, _ k: Int) -> Int { (t / n) % k }
func blinkEyes(_ t: Int) -> Eyes { t % 41 < 2 ? .closed : .open }
func arc(_ t: Int, _ len: Int, _ h: CGFloat) -> CGFloat {
    let x = CGFloat(t % len) / CGFloat(max(len - 1, 1))
    return -h * 4 * x * (1 - x)
}
func arcI(_ t: Int, _ len: Int, _ h: CGFloat) -> Int { Int((arc(t, len, h)).rounded()) }
func wave(_ t: Int, _ speed: Double, _ amp: Double) -> Int { Int((sin(Double(t) * speed) * amp).rounded()) }
func vline(_ n: Int, _ c: Character) -> Sp { Array(repeating: String(c), count: max(n, 0)) }
func hline(_ n: Int, _ c: Character) -> Sp { [String(repeating: c, count: max(n, 0))] }
func diag(_ n: Int, _ c: Character) -> Sp {   // von unten-links nach oben-rechts
    (0..<n).map { i in String(repeating: ".", count: n - 1 - i) + String(c) }
}
func recolor(_ s: Sp, _ map: [Character: Character]) -> Sp {
    s.map { String($0.map { map[$0] ?? $0 }) }
}
func one(_ c: Character) -> Sp { [String(c)] }

// MARK: - Sprites

let steam1: Sp = [".s", "s.", ".s"]
let steam2: Sp = ["s.", ".s", "s."]
let mug: Sp = ["mccm..", "mmmmm.", "mmmm.m", "mmmmm."]
let teaMug = recolor(mug, ["m": "u", "c": "g"])
let z4: Sp = ["llll", "..l.", ".l..", "llll"]
let z3: Sp = ["lll", ".l.", "lll"]
let note: Sp = [".uu", ".u.", ".u.", "uu.", "uu."]
let note2 = recolor(note, ["u": "v"])
let heart: Sp = ["rr.rr", "rrrrr", ".rrr.", "..r.."]
let heartS: Sp = ["r.r", "rrr", ".r."]
let star: Sp = ["..y..", ".yyy.", "yyyyy", ".yyy.", ".y.y."]
let spark: Sp = [".y.", "yyy", ".y."]
let sparkW: Sp = [".w.", "www", ".w."]
let bang: Sp = ["r", "r", "r", ".", "r"]
let quest: Sp = ["uuu", "..u", ".u.", "...", ".u."]
let drop: Sp = [".l.", "lll", ".l."]
let flake: Sp = ["w.w", ".w.", "w.w"]
let book: Sp = ["uwwwkwwwu", "uwwwkwwwu", "uuuuuuuuu"]
let bookFlip: Sp = ["....ww...", "uwwwkwwwu", "uwwwkwwwu", "uuuuuuuuu"]
let headphones: Sp = ["...aaaaaaaaaa...", "..a..........a..", "rr............rr", "rr............rr"]
let guitar: Sp = ["........ss", ".......s..", "bbb...s...", "bbbbbs....", "bkbbb.....", "bbbb......", ".bb......."]
let balls: [Sp] = [["rr", "rr"], ["yy", "yy"], ["uu", "uu"]]
let bubble: Sp = [".l.", "l.l", ".l."]
let bubbleBig: Sp = [".ll.", "l..l", "l..l", ".ll."]
let wandBubble: Sp = [".ss.", "s..s", ".ss.", "..a.", "..a."]
let fish: Sp = [".ggg.g.", "gkggggg", ".ggg.g."]
let pond: Sp = [".uuuuuuu.", "uuuluuuuu"]
let camera: Sp = [".aa.....", "aaaaaaaa", "aaskksaa", "aaskksaa", "aaaaaaaa"]
let flash: Sp = ["w.w.w", ".www.", "wwwww", ".www.", "w.w.w"]
let dumbbell: Sp = ["aa..............aa", "aassssssssssssssaa", "aa..............aa"]
let ropeUp: Sp = ["...bbbbbbbbbb...", "..b..........b..", ".b............b.", "b..............b", "b..............b"]
let ropeDown: Sp = Array(ropeUp.reversed())
let umbrella: Sp = [8, 16, 22, 26, 28].map { w in String(repeating: ".", count: (28 - w) / 2) + String(repeating: "r", count: w) }
    + [String((0..<28).map { $0 % 4 == 3 ? "." : "r" })]
let iceCream: Sp = [".pp.", "pppp", "pwpp", "tttt", ".tt.", ".tt."]
let pizza: Sp = ["tttttt", "yryyry", ".yyyy.", ".yry..", "..y..."]
let balloon: Sp = [".rrr.", "rrrrr", "rwrrr", "rrrrr", ".rrr.", "..r.."]
let wateringCan: Sp = ["u...uuu.", ".u.uuuuu", "..uuuuuu", "...uuuuu"]
let flowerHead: Sp = [".p.", "pyp", ".p."]
let easel: Sp = ["bbbbbbbbbb", "b........b", "b........b", "b........b", "b........b", "b........b", "bbbbbbbbbb", ".b......b.", ".b......b.", "b........b"]
let picture: Sp = ["lllllyyl", "llllyyyy", "lllllyyl", "ggglllll", "gggggggg"]
let brush: Sp = ["r", "b", "b"]
let shades: Sp = ["kkkkkkkkkkkk", ".wkkk..wkkk.", "..kk....kk.."]
let bulbOff: Sp = [".sss.", "s...s", "s...s", ".sss.", ".aaa.", ".aaa."]
let bulbOn: Sp = [".yyy.", "yyyyy", "yywyy", ".yyy.", ".aaa.", ".aaa."]
let sun: Sp = ["y.y.y", ".yyy.", "yyyyy", ".yyy.", "y.y.y"]
let controller: Sp = [".aaaaaaaa.", "aryaaaauaa", "aaaaaaaaaa", ".aa....aa."]
let laptop: Sp = ["..sssssssss", "..sssswssss", "..sssssssss", "aaaaaaaaaaaaa"]
let cakeBase: Sp = ["....w....", "....w....", "mmmmmmmmm", "pwpwpwpwp", "mmmmmmmmm", "ccccccccc"]
let toothbrush: Sp = ["wwssssssu"]
let shovel: Sp = ["b", "b", "b", "b", "b", "sss", ".s."]
let chest: Sp = [".bbbb.", "bbbbbb", "yyyyyy", "bbybbb", "bbbbbb"]
let plane: Sp = ["ww....", ".wwww.", "..wwww", ".wwww.", "ww...."]
let bowl: Sp = ["rwrwrwrw", ".rwrwrw.", "..rrrr.."]
let yoyo: Sp = [".r.", "rrr", ".r."]
let butterflyOpen: Sp = ["p.p", "pkp", "p.p"]
let butterflyShut: Sp = ["...", "pkp", "..."]
let hat: Sp = ["..kkkkkk..", "..kkkkkk..", "..krrrrk..", "kkkkkkkkkk"]
let gum: [Sp] = [["pp"], [".pp.", "pppp", ".pp."], [".ppp.", "ppppp", "ppwpp", "ppppp", ".ppp."],
                 ["..ppp..", ".ppppp.", "pppwppp", "ppppppp", "ppppppp", ".ppppp.", "..ppp.."]]
let gumPop: Sp = ["p...p", ".....", "..p..", ".....", "p...p"]
let soccer: Sp = [".wk.", "wkww", "wwkw", ".kw."]
let wand: Sp = ["y", "k", "k", "k"]
let cloud: Sp = ["..ww.ww..", ".wwwwwwww.", "wwwwwwwwww", "wwwwwwwwww", ".wwwwwwww."]
let pillow: Sp = [".wwwww.", "wwwwwww", ".wwwww."]
let blanket: Sp = ["vvvvvvvvvvvvvv", "vwvvwvvwvvwvvv", "vvvvvvvvvvvvvv"]
let confettiColors: [Character] = ["r", "y", "u", "g", "p", "v"]

// MARK: - Grundzustände

func idleFrame(_ t: Int) -> Frame { F { f in
    f.body.eyes = blinkEyes(t)
    f.dy = ph(t, 6, 2) == 0 ? 0 : -2
}}

func walkFrame(_ t: Int, left: Bool) -> Frame { F { f in
    f.body.legs = ph(t, 2, 2) == 0 ? .stand : .step
    f.body.eyes = blinkEyes(t)
    f.flip = left
    f.dy = ph(t, 2, 2) == 0 ? 0 : -1
}}

func happyFrame(_ t: Int) -> Frame { F { f in
    f.body.eyes = .happy
    f.body.mouth = .smile
    f.body.armL = .up; f.body.armR = .up
    f.dy = arc(t, 8, 26)
    f.front.append((spark, -3, -4 + wave(t, 0.8, 1)))
    f.front.append((star, 17, -6 + wave(t, 0.6, 1)))
}}

func thinkFrame(_ t: Int) -> Frame { F { f in
    f.body.eyes = ph(t, 10, 2) == 0 ? .up : .right
    f.heldBack.append((bulbOff, 6, -8))
    f.front.append((quest, 17 + ph(t, 6, 2), -5))
    f.dy = ph(t, 4, 2) == 0 ? 0 : -1
}}

func laptopFrame(_ t: Int) -> Frame { F { f in
    f.body.legs = .sit
    f.body.eyes = t % 37 < 2 ? .closed : .down
    f.body.armL = ph(t, 2, 2) == 0 ? .down : .side
    f.body.armR = ph(t, 2, 2) == 1 ? .down : .side
    f.held.append((laptop, 1, 4))
    if t % 18 < 3 { f.front.append((sparkW, 16, -1)) }
    f.front.append((hline(1 + ph(t, 3, 3), "l"), 16, 1))
}}

func napFrame(_ t: Int) -> Frame { F { f in
    f.body.legs = .sit
    f.body.eyes = .closed
    f.sy = ph(t, 10, 2) == 0 ? 1 : 1.03
    f.heldBack.append((pillow, -4, 4))
    f.held.append((blanket, 1, 4))
    let a = t % 40, b = (t + 20) % 40
    f.front.append((z4, 15 + a / 10, 0 - a / 4))
    f.front.append((z3, 16 + b / 10, 0 - b / 4))
}}

func drinkFrame(_ t: Int, _ cup: Sp) -> Frame { F { f in
    let sip = ph(t, 12, 3) == 2
    f.body.armR = sip ? .up : .out
    f.body.eyes = sip ? .closed : blinkEyes(t)
    f.held.append((cup, sip ? 15 : 17, sip ? -2 : 0))
    f.front.append((ph(t, 3, 2) == 0 ? steam1 : steam2, sip ? 16 : 18, sip ? -5 : -3))
    if t > 70 { f.body.eyes = .happy; f.body.mouth = .smile; f.front.append((heartS, 7, -4)) }
}}

// MARK: - Animationen

struct Act {
    let name: String
    let len: Int            // Ticks à 0,12 s
    let f: (Int) -> Frame
    init(_ n: String, _ l: Int, _ f: @escaping (Int) -> Frame) { name = n; len = l; self.f = f }
}

let acts: [Act] = [
    Act("Kaffee trinken", 80) { t in drinkFrame(t, mug) },
    Act("Tee trinken", 80) { t in drinkFrame(t, teaMug) },
    Act("Gähnen", 40) { t in F { f in
        if t < 24 {
            f.body.eyes = .closed; f.body.mouth = .o
            f.body.armL = .up; f.body.armR = .up
            f.sy = 1 + 0.12 * CGFloat(sin(Double(t) / 24 * .pi))
        } else { f.body.eyes = t < 30 ? .closed : .open }
    }},
    Act("Nickerchen", 160) { t in napFrame(t) },
    Act("Buch lesen", 110) { t in F { f in
        f.body.legs = .sit
        f.body.eyes = t % 41 < 2 ? .closed : .down
        if t % 36 < 4 { f.held.append((bookFlip, 3, 2)) } else { f.held.append((book, 3, 3)) }
        if t > 100 { f.body.eyes = .happy }
    }},
    Act("Musik hören", 100) { t in F { f in
        f.held.append((headphones, 0, -2))
        f.body.eyes = ph(t, 16, 2) == 0 ? .closed : .happy
        f.dy = ph(t, 4, 2) == 0 ? 0 : -3
        f.rot = ph(t, 8, 2) == 0 ? -3 : 3
        let k = t % 24
        f.front.append((ph(t, 24, 2) == 0 ? note : note2, 17 + k / 8, -2 - k / 3))
    }},
    Act("Tanzen", 96) { t in F { f in
        f.flip = ph(t, 8, 2) == 1
        f.dy = arc(t, 8, 10)
        f.body.armL = ph(t, 4, 2) == 0 ? .up : .side
        f.body.armR = ph(t, 4, 2) == 1 ? .up : .side
        f.body.legs = ph(t, 2, 2) == 0 ? .stand : .step
        f.body.eyes = .happy; f.body.mouth = .smile
        let k = t % 20
        f.front.append((note, -5, -2 - k / 3))
        f.front.append((note2, 19, -6 - k / 4))
    }},
    Act("Gitarre spielen", 100) { t in F { f in
        f.held.append((guitar, 6, 2))
        f.body.armR = ph(t, 3, 2) == 0 ? .side : .down
        f.body.eyes = .closed; f.body.mouth = .small
        f.dy = ph(t, 6, 2) == 0 ? 0 : -1
        let k = t % 24
        f.front.append((note, 18 + k / 10, -3 - k / 3))
        if t % 48 > 24 { f.front.append((note2, 22, -6 - (k / 4))) }
    }},
    Act("Jonglieren", 100) { t in F { f in
        f.body.armL = ph(t, 3, 2) == 0 ? .up : .side
        f.body.armR = ph(t, 3, 2) == 1 ? .up : .side
        f.body.eyes = .up
        for i in 0..<3 {
            let a = Double(t) * 0.35 + Double(i) * 2.094
            f.front.append((balls[i], 7 + Int((7 * cos(a)).rounded()), -4 - Int((6 * abs(sin(a))).rounded())))
        }
    }},
    Act("Seifenblasen", 100) { t in F { f in
        f.body.armR = .up
        f.held.append((wandBubble, 15, -4))
        f.body.eyes = t % 30 < 15 ? .up : .happy
        f.body.mouth = .small
        for i in 0..<4 {
            let k = (t + i * 12) % 48
            f.front.append((k % 16 < 8 ? bubble : bubbleBig, 18 + i * 2 + wave(k, 0.3, 2), -5 - k / 3))
        }
    }},
    Act("Angeln", 130) { t in F { f in
        f.body.legs = .sit
        f.body.armR = .out
        f.held.append((diag(8, "b"), 17, -5))
        f.back.append((pond, 21, 8))
        let bob = ph(t, 10, 2)
        f.held.append((vline(10 + bob, "s"), 25, -5))
        f.body.eyes = blinkEyes(t)
        if t > 85 {
            f.front.append((fish, 22, 2 + arcI(t - 85, 14, 6)))
            f.body.eyes = t > 105 ? .happy : .wide
            if t > 105 { f.front.append((spark, 28, -4)) }
        }
    }},
    Act("Fotografieren", 90) { t in F { f in
        f.held.append((camera, 4, 0))
        f.body.armL = .out; f.body.armR = .out
        let k = t % 30
        if k >= 24 && k < 27 {
            f.front.append((flash, 5, -7))
            f.front.append((sparkW, 14, -4))
            f.dy = -1
        }
        if t > 80 { f.front.append((heartS, 18, -3)) }
    }},
    Act("Hantel stemmen", 96) { t in F { f in
        let up = ph(t, 8, 2) == 0
        f.body.armL = up ? .up : .side
        f.body.armR = up ? .up : .side
        f.held.append((dumbbell, -1, up ? -2 : 3))
        f.body.eyes = up ? .closed : .open
        f.body.mouth = .line
        f.sy = up ? 0.96 : 1
        if t % 24 < 12 { f.front.append((drop, 16, -1 + (t % 24) / 3)) }
    }},
    Act("Seilspringen", 88) { t in F { f in
        let k = t % 8
        f.body.armL = .out; f.body.armR = .out
        f.held.append(k < 4 ? (ropeUp, 0, -2) : (ropeDown, 0, 5))
        f.dy = k >= 3 && k < 7 ? -6 : 0
        f.body.legs = k >= 4 ? .step : .stand
        f.body.eyes = .happy
    }},
    Act("Regenschirm", 110) { t in F { f in
        f.held.append((umbrella, 2, -9))
        f.held.append((vline(6, "a"), 16, -4))
        f.body.armR = .up
        f.body.eyes = t % 40 < 10 ? .up : blinkEyes(t)
        for i in 0..<14 {
            let x = -12 + (i * 7) % 40
            let y = -16 + (t * 2 + i * 7) % 26
            if x >= 2 && x <= 29 && y > -10 { continue }
            f.front.append((["u", "l"], x, y))
        }
    }},
    Act("Schneeflocken fangen", 100) { t in F { f in
        f.body.eyes = .up; f.body.mouth = .o
        f.body.armL = ph(t, 10, 2) == 0 ? .up : .side
        f.body.armR = ph(t, 10, 2) == 1 ? .up : .side
        for i in 0..<9 {
            let x = -10 + (i * 9) % 38 + wave(t + i * 5, 0.2, 1)
            let y = -16 + (t + i * 9) % 25
            f.front.append((flake, x, y))
        }
        if t % 30 < 4 { f.dx = t % 2 == 0 ? -1 : 1 }
    }},
    Act("Eis essen", 90) { t in F { f in
        let bites = min(t / 20, 3)
        f.body.armR = .out
        f.held.append((Array(iceCream.dropFirst(bites)), 17, -3 + bites))
        let biting = t % 20 >= 15
        f.body.mouth = biting ? .o : .smile
        f.body.eyes = biting ? .happy : blinkEyes(t)
    }},
    Act("Pizza essen", 90) { t in F { f in
        let bites = min(t / 20, 3)
        f.body.armR = .out
        f.held.append((Array(pizza.dropFirst(bites)), 17, -2 + bites))
        let biting = t % 20 >= 15
        f.body.mouth = biting ? .o : .smile
        f.body.eyes = biting ? .closed : blinkEyes(t)
        if t > 80 { f.front.append((heartS, 7, -4)) }
    }},
    Act("Luftballon", 120) { t in F { f in
        if t < 70 {
            f.body.armR = .up
            f.body.eyes = .happy
            f.front.append((balloon, 15, -12 + wave(t, 0.2, 1)))
            f.front.append((vline(6, "s"), 17, -6))
        } else {
            let k = t - 70
            f.front.append((balloon, 15 + k / 6, -12 - k / 2))
            f.front.append((vline(4, "s"), 17 + k / 6, -6 - k / 2))
            f.body.eyes = k < 25 ? .wide : .closed
            f.body.mouth = k < 25 ? .o : .line
        }
    }},
    Act("Blume gießen", 120) { t in F { f in
        f.body.armL = .out
        f.body.eyes = .left
        f.held.append((wateringCan, -9, 1))
        if t < 90 { f.front.append((["l", ".", "l"], -10, 3 + (t % 3))) }
        let h = min(t / 14, 6)
        f.back.append((vline(h, "d"), -11, 9 - h))
        if h >= 2 { f.back.append((["d."], -11, 8)) }
        if h >= 4 { f.back.append((flowerHead, -12, 6 - h)) }
        if t > 100 { f.body.eyes = .happy }
    }},
    Act("Malen", 120) { t in F { f in
        f.body.armR = ph(t, 4, 2) == 0 ? .out : .side
        f.body.eyes = .right
        f.held.append((brush, 18, 1))
        f.back.append((easel, 18, -1))
        let n = min(t / 2, 40)
        var pic = Array(repeating: Array(repeating: Character("."), count: 8), count: 5)
        for i in 0..<n { let c = (i * 7) % 40; pic[c / 8][c % 8] = Array(picture[c / 8])[c % 8] }
        f.back.append((pic.map { String($0) }, 19, 0))
        if t > 100 { f.body.eyes = .happy; f.front.append((spark, 29, -3)) }
    }},
    Act("Sonnenbrille", 80) { t in F { f in
        f.held.append((shades, 2, 1))
        f.rot = t > 10 ? -6 : 0
        f.body.mouth = .smile
        f.body.armL = .down
        if t % 20 < 3 { f.front.append((sparkW, 3, -2)) }
    }},
    Act("Verliebt", 90) { t in F { f in
        f.body.eyes = .happy; f.body.mouth = .smile
        f.rot = Double(wave(t, 0.2, 4))
        for i in 0..<3 {
            let k = (t + i * 10) % 30
            f.front.append((i == 1 ? heart : heartS, 2 + i * 6 + wave(k, 0.4, 1), -2 - k / 3))
        }
    }},
    Act("Idee", 70) { t in F { f in
        if t < 20 {
            f.body.eyes = .up
            f.heldBack.append((bulbOff, 6, -8))
        } else {
            f.body.eyes = .wide; f.body.mouth = .o
            f.heldBack.append((bulbOn, 6, -8))
            if t % 6 < 3 { f.held.append((spark, 1, -8)); f.held.append((spark, 12, -8)) }
            if t < 30 { f.dy = arc(t - 20, 10, 12) }
            f.body.armR = .up
        }
    }},
    Act("Niesen", 50) { t in F { f in
        if t < 25 {
            f.body.eyes = .closed
            f.sy = 1 + 0.006 * CGFloat(t)
            f.rot = -Double(t) / 3
            f.body.mouth = t > 15 ? .o : .none
        } else if t < 32 {
            f.dx = t % 2 == 0 ? -3 : 3
            f.body.eyes = .closed; f.body.mouth = .o
            f.front.append((bang, 18, -3))
            f.front.append((sparkW, 18 + (t - 25), 3))
        } else { f.body.eyes = t < 40 ? .dizzy : .open }
    }},
    Act("Schluckauf", 90) { t in F { f in
        let k = t % 22
        if k < 4 {
            f.dy = -6; f.body.eyes = .wide; f.body.mouth = .small
            f.front.append((bang, 17, -4))
        } else { f.body.eyes = blinkEyes(t) }
    }},
    Act("Umschauen", 72) { t in F { f in
        let seq: [Eyes] = [.left, .left, .right, .right, .up, .open]
        f.body.eyes = seq[ph(t, 12, 6)]
        f.flip = ph(t, 12, 6) >= 2 && ph(t, 12, 6) < 4
    }},
    Act("Winken", 60) { t in F { f in
        f.body.armR = ph(t, 4, 2) == 0 ? .up : .out
        f.body.eyes = .happy; f.body.mouth = .smile
        f.rot = ph(t, 8, 2) == 0 ? 2 : -2
    }},
    Act("Strecken", 50) { t in F { f in
        f.body.armL = .up; f.body.armR = .up
        f.sy = 1 + 0.16 * CGFloat(sin(Double(t) / 50 * .pi))
        f.sx = 1 - 0.05 * CGFloat(sin(Double(t) / 50 * .pi))
        f.body.eyes = .closed
        f.body.mouth = t > 15 && t < 35 ? .o : .none
    }},
    Act("Salto", 44) { t in F { f in
        f.dy = arc(t, 44, 34)
        if t >= 8 && t < 36 { f.rot = 360 * Double(t - 8) / 28 }
        f.body.eyes = t < 8 ? .wide : (t < 36 ? .closed : .happy)
        f.body.armL = .up; f.body.armR = .up
        if t >= 36 { f.front.append((star, 18, -5)) }
    }},
    Act("Pirouette", 50) { t in F { f in
        f.flip = ph(t, 2, 2) == 1
        f.dy = -2
        f.body.armL = .up; f.body.armR = .up
        f.body.eyes = .closed
        f.front.append((spark, -3 + wave(t, 0.5, 2), -2))
        f.front.append((sparkW, 18 + wave(t, 0.5, 2), -4))
    }},
    Act("Wackeln", 50) { t in F { f in
        f.dx = t % 2 == 0 ? -2 : 2
        f.rot = t % 2 == 0 ? -4 : 4
        f.body.eyes = .happy; f.body.mouth = .smile
        f.body.legs = t % 2 == 0 ? .stand : .step
    }},
    Act("Frieren", 90) { t in F { f in
        f.body.tint = "q"
        f.dx = t % 2 == 0 ? -1 : 1
        f.body.eyes = .closed; f.body.mouth = .line
        f.body.armL = .down; f.body.armR = .down
        for i in 0..<6 {
            f.front.append((flake, -8 + i * 7, -14 + (t + i * 6) % 22))
        }
    }},
    Act("Hitze", 90) { t in F { f in
        f.front.append((sun, 22, -14))
        if t % 8 < 4 { f.front.append((["y.y"], 22, -9)) }
        f.sy = 0.96; f.sx = 1.03
        f.body.eyes = .closed; f.body.mouth = .o
        f.front.append((drop, 1, 0 + (t % 12) / 2))
        f.front.append((drop, 15, 1 + ((t + 6) % 12) / 2))
    }},
    Act("Pfeifen", 80) { t in F { f in
        f.body.eyes = .closed; f.body.mouth = .small
        f.dy = ph(t, 5, 2) == 0 ? 0 : -1
        let k = t % 24
        f.front.append((note, 17 + k / 6, 1 - k / 3))
    }},
    Act("Sterne gucken", 130) { t in F { f in
        f.body.legs = .sit
        f.body.eyes = .up
        let pts = [(-8, -10), (-2, -15), (5, -11), (12, -16), (20, -9), (25, -14)]
        for (i, p) in pts.enumerated() {
            f.back.append(((t / 4 + i) % 3 == 0 ? spark : one("y"), p.0, p.1))
        }
        if t >= 60 && t < 78 {
            let k = t - 60
            f.front.append((["ssy"], -10 + k * 2, -18 + k / 2))
            f.body.eyes = .wide
        }
        if t >= 78 { f.body.eyes = .happy }
    }},
    Act("Videospiel", 96) { t in F { f in
        f.body.legs = .sit
        f.held.append((controller, 3, 4))
        f.body.eyes = .down
        f.body.armL = ph(t, 2, 2) == 0 ? .down : .side
        f.body.armR = ph(t, 3, 2) == 0 ? .down : .side
        if t > 80 {
            f.dy = arc(t - 80, 16, 14)
            f.body.eyes = .happy
            f.front.append((star, 18, -6))
        }
    }},
    Act("Am Laptop", 100) { t in laptopFrame(t) },
    Act("Geburtstag", 120) { t in F { f in
        f.back.append((cakeBase, -11, 3))
        f.body.eyes = .left
        if t < 70 {
            f.back.append((one(ph(t, 2, 2) == 0 ? "y" : "o"), -7, 2))
            if t > 55 { f.body.mouth = .o; f.front.append((["s.s"], -4, 4)) }
        } else {
            f.back.append(([".s", "s."], -7 + ph(t, 4, 2), 0 - (t - 70) / 6))
            f.body.eyes = .happy; f.body.mouth = .smile
            if t < 86 { f.dy = arc(t - 70, 16, 16) }
            for i in 0..<10 {
                let c = confettiColors[i % confettiColors.count]
                f.front.append((one(c), -8 + (i * 5) % 34, -12 + (t + i * 3) % 20))
            }
        }
    }},
    Act("Zähneputzen", 80) { t in F { f in
        f.body.armR = .out
        f.held.append((toothbrush, 8 + ph(t, 2, 2), 4))
        f.held.append((["w.w", ".w."], 5, 5))
        f.body.eyes = ph(t, 16, 2) == 0 ? .closed : .open
        f.dx = ph(t, 2, 2) == 0 ? 0 : 1
    }},
    Act("Meditieren", 130) { t in F { f in
        f.body.legs = .sit
        f.body.eyes = .closed
        f.body.armL = .down; f.body.armR = .down
        f.dy = -6 - CGFloat(sin(Double(t) / 10)) * 4
        if t % 16 < 8 { f.front.append((spark, -4, 0)); f.front.append((spark, 18, 0)) }
        else { f.front.append((one("y"), -3, 1)); f.front.append((one("y"), 19, 1)) }
    }},
    Act("Schatzsuche", 120) { t in F { f in
        f.body.armR = .out
        f.body.eyes = .down
        if t < 90 {
            let dig = ph(t, 6, 2) * 2
            f.held.append((shovel, 17, -1 + dig))
            if dig == 0 { f.front.append(([".c", "c.c"], 20 + (t % 6), 4 - (t % 6))) }
        } else {
            f.held.append((shovel, 17, -1))
            f.front.append((chest, 20, 5))
            f.front.append((t % 6 < 3 ? spark : sparkW, 22, 1))
            f.body.eyes = t < 100 ? .wide : .happy
            if t >= 100 { f.dy = arc(t - 100, 10, 10) }
        }
    }},
    Act("Papierflieger", 80) { t in F { f in
        if t < 15 {
            f.body.armR = .up
            f.held.append((plane, 15, -3))
            f.body.eyes = .right
        } else {
            let k = t - 15
            f.body.armR = .out
            f.front.append((plane, 17 + k, -3 - k / 3 + wave(k, 0.3, 1)))
            f.body.eyes = k < 30 ? .right : .happy
        }
    }},
    Act("Popcorn", 100) { t in F { f in
        f.body.legs = .sit
        f.held.append((bowl, 4, 4))
        for i in 0..<4 {
            let k = (t + i * 7) % 18
            f.held.append((one(i % 2 == 0 ? "w" : "y"), 5 + i * 2, 3 + arcI(k, 18, 6)))
        }
        let eat = t % 24 >= 18
        f.body.armR = eat ? .up : .side
        f.body.mouth = eat ? .o : .smile
        f.body.eyes = eat ? .closed : .down
    }},
    Act("Jo-Jo", 80) { t in F { f in
        f.body.armR = .out
        let l = Int((6 * abs(sin(Double(t) * 0.15))).rounded())
        f.held.append((vline(l, "s"), 17, 4))
        f.held.append((yoyo, 16, 4 + l))
        f.body.eyes = l > 3 ? .down : .right
    }},
    Act("Schmetterling", 110) { t in F { f in
        var x = 8 + Int((13 * sin(Double(t) * 0.08)).rounded())
        var y = -7 + Int((4 * sin(Double(t) * 0.16)).rounded())
        if t > 95 { x = 7; y = -3 }
        f.front.append((t > 95 || t % 4 < 2 ? butterflyShut : butterflyOpen, x, y))
        f.body.eyes = t > 95 ? .up : (x < 3 ? .left : (x > 12 ? .right : .up))
        if t > 95 { f.body.mouth = .smile }
    }},
    Act("Kopfstand", 76) { t in F { f in
        if t < 10 { f.sy = 0.9 }
        else if t < 20 { f.rot = 180 * Double(t - 10) / 10; f.dy = -10 }
        else if t < 60 {
            f.rot = 180; f.dy = 0
            f.body.legs = ph(t, 3, 2) == 0 ? .stand : .step
            f.body.eyes = .wide
        } else if t < 70 { f.rot = 180 - 180 * Double(t - 60) / 10; f.dy = -10 }
        else { f.body.eyes = .dizzy }
    }},
    Act("Hut ziehen", 60) { t in F { f in
        let lift = t >= 20 && t < 40
        f.held.append((hat, 3, lift ? -7 : -4))
        f.body.armR = lift ? .up : .side
        f.body.eyes = lift ? .happy : blinkEyes(t)
        f.body.mouth = lift ? .smile : .none
        f.rot = lift ? 4 : 0
    }},
    Act("Kaugummiblase", 80) { t in F { f in
        if t < 60 {
            let g = gum[min(t / 15, 3)]
            f.held.append((g, 8 - g[0].count / 2, 5 - g.count / 2))
            f.body.eyes = t > 45 ? .wide : .open
        } else if t < 66 {
            f.held.append((gumPop, 5, 2))
            f.body.eyes = .closed
            f.dy = -2
        } else {
            f.held.append((["p..p", ".pp."], 6, 4))
            f.body.eyes = .dizzy
        }
    }},
    Act("Fußball", 100) { t in F { f in
        if t < 80 {
            let k = t % 12
            f.front.append((soccer, 6, -4 + arcI(k, 12, 8)))
            f.dy = k < 2 ? -2 : 0
            f.body.eyes = .up
        } else {
            let k = t - 80
            f.front.append((soccer, 15 + k * 2, 5 + arcI(k, 20, 10)))
            f.body.legs = k < 4 ? .step : .stand
            f.body.eyes = .happy
        }
    }},
    Act("Zaubern", 96) { t in F { f in
        f.body.armR = .up
        f.held.append((wand, 16, -4))
        let a = Double(t) * 0.5
        f.front.append((t % 4 < 2 ? spark : sparkW, 17 + Int((3 * cos(a)).rounded()), -6 + Int((3 * sin(a)).rounded())))
        f.body.eyes = t < 50 ? .up : .wide
        if t >= 50 {
            f.front.append((star, 20, -8))
            f.back.append((vline(3, "d"), 23, 6))
            f.back.append((flowerHead, 22, 3))
            if t > 66 { f.body.eyes = .happy; f.body.mouth = .smile }
        }
    }},
    Act("Einnicken", 100) { t in F { f in
        if t < 20 { f.body.eyes = blinkEyes(t) }
        else if t < 80 {
            f.body.eyes = .closed
            f.dy = CGFloat(min((t - 20) / 15, 3))
            f.sy = 0.96
            if t % 20 < 10 { f.front.append((z3, 15, -2)) }
        } else if t < 88 {
            f.dy = -6; f.body.eyes = .wide
            f.front.append((bang, 17, -4))
        } else { f.body.eyes = .open }
    }},
    Act("Tagträumen", 90) { t in F { f in
        f.body.eyes = .up; f.body.mouth = .smile
        f.front.append((one("w"), 14, -2))
        f.front.append((["ww"], 15, -5))
        f.front.append((cloud, 13, -12))
        f.front.append((ph(t, 30, 2) == 0 ? heartS : recolor(mug, ["m": "s", "c": "c"]), 16, -11))
        f.rot = Double(wave(t, 0.1, 3))
    }},
    Act("Lachen", 60) { t in F { f in
        f.body.eyes = .happy; f.body.mouth = .o
        f.dx = ph(t, 2, 2) == 0 ? -1 : 1
        f.dy = ph(t, 6, 2) == 0 ? 0 : -3
        if t % 10 < 5 { f.front.append((sparkW, 17, -3)) }
    }},
]

// Tageszeit beeinflusst, was er gerade gern macht.
func pickAct(hour: Int) -> Int {
    let morning = ["Kaffee trinken", "Tee trinken", "Strecken", "Zähneputzen", "Gähnen"]
    let night = ["Nickerchen", "Sterne gucken", "Einnicken", "Gähnen", "Tagträumen", "Buch lesen"]
    let weights: [Double] = acts.map { a in
        if (6...10).contains(hour) && morning.contains(a.name) { return 4 }
        if (hour >= 21 || hour < 6) && night.contains(a.name) { return 4 }
        return 1
    }
    var r = Double.random(in: 0..<weights.reduce(0, +))
    for (i, w) in weights.enumerated() { r -= w; if r < 0 { return i } }
    return 0
}
