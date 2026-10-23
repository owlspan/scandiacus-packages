// A lit, spinning cube - the gl package end to end.
//
//     scandiacus get gl
//     scandiacus run cube.scd
//
// Drag with the mouse to turn it, Esc to quit. --frames 60 stops after
// that many frames and prints the pixel at the middle, which is how it
// is checked without anyone watching.

import "gl"

const VERTEX = `#version 330 core
layout(location = 0) in vec3 pos;
layout(location = 1) in vec3 normal;
uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;
out vec3 worldPos;
out vec3 worldNormal;
void main() {
    vec4 p = model * vec4(pos, 1.0);
    worldPos = p.xyz;
    worldNormal = mat3(model) * normal;
    gl_Position = proj * view * p;
}
`

const FRAGMENT = `#version 330 core
in vec3 worldPos;
in vec3 worldNormal;
uniform vec3 eye;
uniform vec3 color;
out vec4 frag;
void main() {
    vec3 n = normalize(worldNormal);
    vec3 l = normalize(vec3(0.6, 0.8, 0.5));
    vec3 v = normalize(eye - worldPos);
    vec3 h = normalize(l + v);
    float diffuse = max(dot(n, l), 0.0);
    float spec = pow(max(dot(n, h), 0.0), 48.0);
    vec3 c = color * (0.15 + 0.85 * diffuse) + vec3(0.6) * spec;
    frag = vec4(pow(c, vec3(1.0 / 2.2)), 1.0);
}
`

// Six faces, two triangles each, position then normal per vertex.
fn cubeVertices() -> []float {
    let out: []float = []
    // normal, then the two axes that span the face
    let faces = [
        [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
        [-1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0],
        [0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0],
        [0.0, -1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0],
        [0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0]]
    // the corners of a face, counter-clockwise seen from outside
    let corners = [-1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0, 1.0, -1.0, 1.0]
    for f in faces {
        for k in 0..6 {
            let a = corners[k * 2]
            let b = corners[k * 2 + 1]
            for i in 0..3 {
                push(out, (f[i] + a * f[3 + i] + b * f[6 + i]) * 0.5)
            }
            for i in 0..3 {
                push(out, f[i])
            }
        }
    }
    return out
}

let frames = toInt(args.value("frames", "0"))

let w = must(win.open("gl - cube", 800, 600))
let g = must(glOpen(w))
glVsync(true)
print(glVersion())

let prog = must(glProgram(VERTEX, FRAGMENT))
let uModel = glGetUniformLocation(prog, "model")
let uView = glGetUniformLocation(prog, "view")
let uProj = glGetUniformLocation(prog, "proj")
let uEye = glGetUniformLocation(prog, "eye")
let uColor = glGetUniformLocation(prog, "color")

let vao = glGenVertexArray()
glBindVertexArray(vao)
let vbo = glGenBuffer()
glBindBuffer(GL_ARRAY_BUFFER, vbo)
glBufferFloats(GL_ARRAY_BUFFER, cubeVertices(), GL_STATIC_DRAW)
glAttribFloats(0, 3, 6, 0)
glAttribFloats(1, 3, 6, 3)

glEnable(GL_DEPTH_TEST)
glEnable(GL_CULL_FACE)

let yaw = 0.6
let pitch = 0.4
let lastX = 0
let lastY = 0
let start = time.millis()
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

    let t = float(time.millis() - start) / 1000.0
    let aspect = float(win.width(w)) / float(win.height(w))
    let model = glmMul(glmRotate(pitch, 1.0, 0.0, 0.0), glmRotate(yaw, 0.0, 1.0, 0.0))

    glClearColor(0.07, 0.08, 0.11, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glUseProgram(prog)
    glUniformMat4(uModel, model)
    glUniformMat4(uView, glmLookAt(0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0))
    glUniformMat4(uProj, glmPerspective(0.9, aspect, 0.1, 100.0))
    glUniform3f(uEye, 0.0, 0.0, 3.0)
    glUniform3f(uColor, 0.85, 0.45 + 0.2 * sin(t), 0.25)
    glDrawArrays(GL_TRIANGLES, 0, 36)

    frame += 1
    if frames > 0 && frame >= frames {
        print("middle: {glReadPixel(400, 300)}")
        print("corner: {glReadPixel(5, 5)}")
        let e = glErrorText()
        print("error: \"{e}\"")
        break
    }
    glSwap(g)
}

glClose(g)
win.close(w)
