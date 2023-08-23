/* 
    This work is licensed under a Creative Commons Attribution 3.0 Unported License.
    So you are free to share, modify and adapt it for your needs, and even use it for commercial use.
*/
shader_type spatial;
render_mode blend_mix, specular_schlick_ggx, cull_disabled, shadows_disabled;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float speed : hint_range(-1,1) = 0.0;
 
//colors
uniform sampler2D noise1; //add Godot noise here
uniform sampler2D noise2; //add Godot noise here
uniform sampler2D normalmap : hint_normal; //add Godot noise here, enable as_normalmap
uniform vec4 color : source_color;
uniform vec4 trans_color : source_color;
uniform vec4 edge_color : source_color;
 
//foam
uniform float edge_scale = 0.25;
uniform float near = 0.1;
uniform float far = 100.0;
 
//waves
uniform vec2 wave_strengh = vec2(0.5, 0.25);
uniform vec2 wave_frequency = vec2(12.0, 12.0);
uniform vec2 time_factor = vec2(1.0, 2.0);
 
//triplanar
uniform bool use_triplanar = true;
varying vec3 uv1_triplanar_pos;
uniform float uv1_blend_sharpness;
varying vec3 uv1_power_normal;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;
 
//distance_fade
uniform bool use_distance_fade = true;
uniform float distance_fade_min;
uniform float distance_fade_max;
 
 
 
 
 
float rim(float depth){
	depth = 2.0 * depth - 1.0;
	return near * far / (far + depth * (near - far));
}
 
 
float waves(vec2 pos, float time){
	return (wave_strengh.y * sin(pos.y * wave_frequency.y + time * time_factor.y)) + (wave_strengh.x * sin(pos.x * wave_frequency.x + time * time_factor.x));
}
 
void vertex() {
	TANGENT = vec3(0.0,0.0,-1.0) * abs(NORMAL.x);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.y);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0,-1.0,0.0) * abs(NORMAL.x);
	BINORMAL+= vec3(0.0,0.0,1.0) * abs(NORMAL.y);
	BINORMAL+= vec3(0.0,-1.0,0.0) * abs(NORMAL.z);
	BINORMAL = normalize(BINORMAL);
	uv1_power_normal=pow(abs(NORMAL),vec3(uv1_blend_sharpness));
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	uv1_triplanar_pos = VERTEX * uv1_scale + uv1_offset;
	uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
	VERTEX.y += waves(VERTEX.xy, TIME);
}
 
vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos,float time) {
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,p_triplanar_pos.xy + time) * p_weights.z;
	samp+= texture(p_sampler,p_triplanar_pos.xz + time) * p_weights.y;
	samp+= texture(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0) + time) * p_weights.x;
	return samp;
}
 
 
void fragment(){
//	vec4 albedo_tex = triplanar_texture(texture_albedo,uv1_power_normal,uv1_triplanar_pos);
	vec3 n1;
	vec3 n2;
	float time = TIME * speed;
	vec4 normaltex;
	if (use_triplanar == true){
		n1 = triplanar_texture(noise1,uv1_power_normal,uv1_triplanar_pos,time).rgb;
		n2 = triplanar_texture(noise2,uv1_power_normal,uv1_triplanar_pos,(-time*0.2)).rgb;
		normaltex = triplanar_texture(normalmap,uv1_power_normal,uv1_triplanar_pos,(time));
 }
	else {
		n1 = texture(noise1, UV + time).rgb;
		n2 = texture(noise2, UV - time * -0.2).rgb;
 
	}
 
	vec2 uv_movement = UV * 4.0;
	uv_movement += TIME * speed * 4.0;
 
	float sum = (n1.r + n2.r) - 1.0;
 
 
	float z_depth = rim(texture(DEPTH_TEXTURE, SCREEN_UV).x);
	float z_pos = rim(FRAGCOORD.z);
	float diff = z_depth - z_pos;
 
	vec2 displacement = vec2(sum * 0.05);
	diff += displacement.x * 50.0;
 
 
	vec4 col = mix(edge_color, color, step(edge_scale, diff));
 
	vec4 alpha = vec4(1.0);
	alpha = texture(SCREEN_TEXTURE, SCREEN_UV + displacement);
 
 
	float fin = 0.0;
	if (sum > 0.0 && sum < 0.4) fin = 0.1;
	if (sum > 0.4 && sum < 0.8) fin = 0.0;
	if (sum > 0.8) fin = 1.0;
 
 
	ALBEDO = vec3(fin) + mix(alpha.rgb, col.rgb, color.a);
	if (use_distance_fade == true) ALPHA*=clamp(smoothstep(distance_fade_min,distance_fade_max,-VERTEX.z),0.0,1.0);
 	if (use_triplanar == true) NORMAL_MAP = normaltex.rgb;
	else NORMAL_MAP = texture(normalmap, uv_movement).rgb;
 
	ROUGHNESS = 0.04;
	SPECULAR = 0.2;
	BACKLIGHT = trans_color.rgb + fin;
	}
