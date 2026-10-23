// A spinning cube in Vulkan - the vulkan package end to end.
//
//     scandiacus get vulkan
//     scandiacus run cube.scd
//
// Drag with the mouse to turn it, Esc to quit. --frames 60 stops after
// that many frames and prints the pixel at the middle, which is how it
// is checked without anyone watching.
//
// The two shaders are SPIR-V written out as hex so the example needs no
// shader compiler. They are what glslc makes of this GLSL:
//
//     // vertex
//     layout(push_constant) uniform PC { mat4 mvp; } pc;
//     layout(location = 0) in vec3 pos;
//     layout(location = 1) in vec3 col;
//     layout(location = 0) out vec3 vcol;
//     void main() { gl_Position = pc.mvp * vec4(pos, 1.0); vcol = col; }
//
//     // fragment
//     layout(location = 0) in vec3 vcol;
//     layout(location = 0) out vec4 frag;
//     void main() { frag = vec4(vcol, 1.0); }
//
// For your own, write the GLSL, run glslc shader.vert -o shader.vert.spv,
// and load it with bytes.read.

import "vulkan"

const VERTEX_SPV = `030223070000010000000000200000000000000011000200010000000e000300
00000000010000000f00090000000000010000006d61696e0000000002000000
03000000040000000500000047000400020000001e0000000000000047000400
030000001e0000000100000047000400040000001e0000000000000047000400
050000000b000000000000004700030006000000020000004800040006000000
0000000005000000480005000600000000000000230000000000000048000500
0600000000000000070000001000000013000200080000002100030009000000
08000000160003000a00000020000000170004000b0000000a00000003000000
170004000c0000000a00000004000000180004000d0000000c00000004000000
1e000300060000000d000000200004000e000000090000000600000020000400
0f000000010000000b0000002000040010000000030000000b00000020000400
11000000030000000c000000150004001200000020000000010000002b000400
1200000013000000000000002b0004000a000000140000000000803f20000400
15000000090000000d0000003b0004000e00000007000000090000003b000400
0f00000002000000010000003b0004000f00000003000000010000003b000400
1000000004000000030000003b00040011000000050000000300000036000500
08000000010000000000000009000000f8000200160000004100050015000000
1700000007000000130000003d0004000d00000018000000170000003d000400
0b0000001900000002000000510005000a0000001a0000001900000000000000
510005000a0000001b0000001900000001000000510005000a0000001c000000
1900000002000000500007000c0000001d0000001a0000001b0000001c000000
14000000910005000c0000001e000000180000001d0000003e00030005000000
1e0000003d0004000b0000001f000000030000003e000300040000001f000000
fd00010038000100`

const FRAGMENT_SPV = `030223070000010000000000120000000000000011000200010000000e000300
00000000010000000f00070004000000010000006d61696e0000000002000000
0300000010000300010000000700000047000400020000001e00000000000000
47000400030000001e0000000000000013000200040000002100030005000000
0400000016000300060000002000000017000400070000000600000003000000
1700040008000000060000000400000020000400090000000100000007000000
200004000a00000003000000080000002b000400060000000b0000000000803f
3b0004000900000002000000010000003b0004000a0000000300000003000000
3600050004000000010000000000000005000000f80002000c0000003d000400
070000000d0000000200000051000500060000000e0000000d00000000000000
51000500060000000f0000000d00000001000000510005000600000010000000
0d000000020000005000070008000000110000000e0000000f00000010000000
0b0000003e0003000300000011000000fd00010038000100`

// Six faces, two triangles each: position, then color, per vertex.
fn cubeVertices() -> []float {
    let out: []float = []
    // normal, the two axes spanning the face, and the face's color
    let faces = [
        [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.90, 0.30, 0.25],
        [-1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.25, 0.75, 0.35],
        [0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.25, 0.45, 0.90],
        [0.0, -1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.95, 0.80, 0.25],
        [0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.85, 0.35, 0.85],
        [0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.30, 0.85, 0.90]]
    let corners = [-1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0, 1.0, -1.0, 1.0]
    for f in faces {
        for k in 0..6 {
            let a = corners[k * 2]
            let b = corners[k * 2 + 1]
            for i in 0..3 {
                push(out, (f[i] + a * f[3 + i] + b * f[6 + i]) * 0.5)
            }
            for i in 0..3 {
                push(out, f[9 + i])
            }
        }
    }
    return out
}

let frames = toInt(args.value("frames", "0"))

let w = must(win.open("vulkan - cube", 800, 600))
let v = must(vkOpen(w))
let pipe = must(vkPipeline(v, must(vkSpirvHex(VERTEX_SPV)), must(vkSpirvHex(FRAGMENT_SPV)), [3, 3], 64))
let mesh = must(vkVertices(v, cubeVertices()))

let yaw = 0.6
let pitch = 0.4
let lastX = 0
let lastY = 0
let frame = 0

while win.poll(w) {
    if win.pressed(w, "esc") { break }

    if win.mouseDown(w) {
        yaw = yaw + float(win.mouseX(w) - lastX) * 0.01
        pitch = pitch + float(win.mouseY(w) - lastY) * 0.01
    } else {
        yaw = yaw + 0.01
    }
    lastX = win.mouseX(w)
    lastY = win.mouseY(w)

    let aspect = float(v.width) / float(v.height)
    let model = vkmMul(vkmRotate(pitch, 1.0, 0.0, 0.0), vkmRotate(yaw, 0.0, 1.0, 0.0))
    let view = vkmLookAt(0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0)
    let mvp = vkmMul(vkmPerspective(0.9, aspect, 0.1, 100.0), vkmMul(view, model))

    if vkBegin(v, 0.07, 0.08, 0.11) {
        vkBind(v, pipe)
        vkPush(v, pipe, mvp)
        vkDraw(v, mesh, 36)
        frame += 1
        if frames > 0 && frame >= frames {
            print("middle: {vkEndRead(v, 400, 300)}")
            break
        }
        vkEnd(v)
    }
}

vkFreeBuffer(v, mesh)
vkFreePipeline(v, pipe)
vkClose(v)
win.close(w)
