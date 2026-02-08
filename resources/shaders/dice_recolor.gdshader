shader_type canvas_item;

// dice_recolor.gdshader
// 주사위의 그레이스케일 데이터를 기반으로 색상을 입히는 쉐이더
// self_modulate와 하단 COLOR 연산을 통합하여 색상 겹침 문제를 방지함

uniform sampler2D colormap : source_color;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// RGB 값 중 최댓값을 그레이스케일 기준으로 사용
	float grey = max(max(tex_color.r, tex_color.g), tex_color.b);
	
	// 컬러맵이 설정되어 있다면 맵핑된 색상을 사용, 없다면 흰색 기준
	vec4 mapped_color = texture(colormap, vec2(grey, 0.0));
	
	// 최종 출력 컬러 = (텍스처 색상 또는 맵핑 색상) * 노드의 modulate 색상
	// 대비를 위해 밝기 배율을 1.5로 상향 조정함
	COLOR.rgb = tex_color.rgb * COLOR.rgb * 1.5;
	COLOR.a = tex_color.a * COLOR.a;
}