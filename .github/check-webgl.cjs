// Enforce the kit’s browser compatibility convention, then compile and link
// the scene that exposed the difference.
const { execFileSync } = require('node:child_process');
const { readFileSync } = require('node:fs');

function checkIdentifiers() {
    const paths = execFileSync('git', ['ls-files', '-z', '--', '*.glsl'], { encoding: 'utf8' })
        .split('\0').filter(Boolean);
    let invalid = false;
    for (const path of paths) {
        const source = readFileSync(path, 'utf8').replace(
            /\/\*[\s\S]*?\*\/|\/\/[^\n]*|^[ \t]*#\s*include\b[^\n]*/gm,
            text => text.replace(/[^\n]/g, ' ')
        );
        for (const match of source.matchAll(/\b[A-Za-z_][A-Za-z_0-9]*\b/g)) {
            if (!match[0].includes('__')) continue;
            const line = source.slice(0, match.index).split('\n').length;
            console.error(`${path}:${line}: avoid double underscores in GLSL identifier ${match[0]} for browser compatibility`);
            invalid = true;
        }
    }
    if (invalid) throw new Error('GLSL uses double-underscore identifiers that can fail in browsers');
}

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

async function main() {
    checkIdentifiers();
    await checkScene();
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
