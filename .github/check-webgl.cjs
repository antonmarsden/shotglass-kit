// Compile and link the simplex-flow scene in Chromium WebGL 2.
const { readFileSync } = require('node:fs');

async function checkScene() {
    const { chromium } = require('playwright');
    const noise = readFileSync('core/noise.glsl', 'utf8');
    const scene = readFileSync('tests/film/scenes/simplex-flow.glsl', 'utf8');
    const include = '#include <kit/noise.glsl>';
    if (!scene.includes(include)) throw new Error('Missing noise include in simplex-flow scene');
    const fragment = `#version 300 es
precision highp float;
precision highp int;
uniform vec3 iResolution;
uniform float iShotProgress;
out vec4 color;
${scene.replace(include, () => noise)}
void main() { mainImage(color, gl_FragCoord.xy); }`;

    const browser = await chromium.launch({
        executablePath: process.env.CHROME_BIN,
        args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
    });
    try {
        const page = await browser.newPage();
        await page.evaluate(source => {
            const gl = document.createElement('canvas').getContext('webgl2');
            if (!gl) throw new Error('Could not create a WebGL 2 context');

            function compile(type, shaderSource) {
                const shader = gl.createShader(type);
                gl.shaderSource(shader, shaderSource);
                gl.compileShader(shader);
                if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                    throw new Error(gl.getShaderInfoLog(shader));
                }
                return shader;
            }

            const program = gl.createProgram();
            gl.attachShader(program, compile(gl.VERTEX_SHADER,
                '#version 300 es\nvoid main() { gl_Position = vec4(0.0, 0.0, 0.0, 1.0); }'));
            gl.attachShader(program, compile(gl.FRAGMENT_SHADER, source));
            gl.linkProgram(program);
            if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
                throw new Error(gl.getProgramInfoLog(program));
            }
        }, fragment);
        console.log('Chromium WebGL 2 compiled and linked the simplex-flow scene');
    } finally {
        await browser.close();
    }
}

checkScene().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
