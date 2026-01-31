shader_type canvas_item;

// 没给pix 都会触发这个函数
void fragment() {
	// Called for every pixel the material is visible on.
	// 获取texutre坐标
	vec4 input_color = texture(TEXTURE, UV);
	// 填充坐标透明值
	float color_average = (input_color.r + input_color.g + input_color.b) /3.0;
	vec4 output_color = vec4(color_average, color_average, color_average, input_color.a);
	if (output_color.r > 0.8 && output_color.g > 0.8 && output_color.b > 0.8 ){
		//output_color.a =0.0;
		output_color = vec4(1.0, 0.0, 0.0, 1.0);
	}
	COLOR = output_color;
	
	//COLOR = vec4(0.05, input_color.g, input_color.b, input_color.a);
}
