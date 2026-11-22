// 几个着色器共用的噪声。不依赖贴图。

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x00 = mix(hash13(cell), hash13(cell + vec3(1.0, 0.0, 0.0)), f.x);
	float x10 = mix(hash13(cell + vec3(0.0, 1.0, 0.0)), hash13(cell + vec3(1.0, 1.0, 0.0)), f.x);
	float x01 = mix(hash13(cell + vec3(0.0, 0.0, 1.0)), hash13(cell + vec3(1.0, 0.0, 1.0)), f.x);
	float x11 = mix(hash13(cell + vec3(0.0, 1.0, 1.0)), hash13(cell + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

// 每叠一层就把坐标转一下。不转的话噪声的格子和墙面、地板是对齐的，会看出一块一块的方格。
const mat3 OCTAVE_TURN = mat3(vec3(0.0, 0.8, 0.6), vec3(-0.8, 0.36, -0.48), vec3(-0.6, -0.48, 0.64));

float fbm(vec3 p) {
	float sum = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 3; i++) {
		p = OCTAVE_TURN * p;
		sum += value_noise(p) * weight;
		p = p * 2.03 + vec3(17.1, 3.7, 9.2);
		weight *= 0.5;
	}
	return sum / 0.875;
}
