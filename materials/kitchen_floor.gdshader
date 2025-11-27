shader_type spatial;

// Kitchen tile floor shader - cartoon style checkered pattern
// Matches the classic cartoon kitchen aesthetic with blue tiles

uniform vec3 tile_color_light : source_color = vec3(0.4, 0.55, 0.75); // Light blue
uniform vec3 tile_color_dark : source_color = vec3(0.2, 0.35, 0.55);  // Dark blue
uniform vec3 grout_color : source_color = vec3(0.7, 0.75, 0.8);       // Light gray grout
uniform float tile_size : hint_range(0.5, 4.0) = 2.0;                  // Match your grid size
uniform float grout_width : hint_range(0.0, 0.15) = 0.03;
uniform float tile_bevel : hint_range(0.0, 0.1) = 0.02;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.4;
uniform float specular_value : hint_range(0.0, 1.0) = 0.3;

// Simple cartoon shading - less realistic, more stylized
uniform bool cartoon_style = true;
uniform float ambient_boost : hint_range(0.0, 0.5) = 0.2;

void fragment() {
    // Scale UV to tile size
    vec2 scaled_uv = UV * (40.0 / tile_size); // 40 is ground plane size
    
    // Get tile coordinates
    vec2 tile_coord = floor(scaled_uv);
    vec2 tile_uv = fract(scaled_uv);
    
    // Checkerboard pattern
    float checker = mod(tile_coord.x + tile_coord.y, 2.0);
    
    // Grout detection (edges of each tile)
    float grout_mask = 0.0;
    if (tile_uv.x < grout_width || tile_uv.x > (1.0 - grout_width) ||
        tile_uv.y < grout_width || tile_uv.y > (1.0 - grout_width)) {
        grout_mask = 1.0;
    }
    
    // Bevel effect - darken edges slightly for depth
    float bevel_mask = 0.0;
    float bevel_edge = grout_width + tile_bevel;
    if (tile_uv.x < bevel_edge || tile_uv.x > (1.0 - bevel_edge) ||
        tile_uv.y < bevel_edge || tile_uv.y > (1.0 - bevel_edge)) {
        bevel_mask = 0.15;
    }
    
    // Select tile color based on checker pattern
    vec3 tile_color = mix(tile_color_dark, tile_color_light, checker);
    
    // Apply bevel darkening
    tile_color = tile_color * (1.0 - bevel_mask);
    
    // Mix in grout
    vec3 final_color = mix(tile_color, grout_color, grout_mask);
    
    // Cartoon style: boost colors and reduce shading complexity
    if (cartoon_style) {
        final_color = final_color + vec3(ambient_boost);
        final_color = clamp(final_color, vec3(0.0), vec3(1.0));
    }
    
    ALBEDO = final_color;
    ROUGHNESS = roughness_value;
    SPECULAR = specular_value;
    
    // Slight metallic for that shiny cartoon floor look
    METALLIC = 0.0;
}
