my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;

image_test: Simp.Texture;

screenshot_index := 0;
last_draw :float64;

draw_one_frame :: () {
    Simp.clear_render_target(.15, .08, .08, 1);

    Simp.set_shader_for_color();

    time := seconds_since_init();

    // This is our own code to set up a rotating square:
    {
        b := cast(float)window_height / 10;
        p: Vector2;
        p.x = cast(float)(window_width  / 2);
        p.y = cast(float)(window_height / 2);

        theta := cast(float) fmod_cycling(time, TAU);

        ct := cos(theta);
        st := sin(theta);

        w := Vector2.{b*ct, b*st};
        h := Vector2.{b*st, -b*ct};

        p0 := p - w - h;
        p1 := p + w - h;
        p2 := p + w + h;
        p3 := p - w + h;

        a :: 1.0;
        c0 := Vector4.{1, 0, 0, a};
        c1 := Vector4.{0, 1, 0, a};
        c2 := Vector4.{0, 0, 1, a};
        c3 := Vector4.{1, 1, 1, a};

        Simp.immediate_quad(p0, p1, p2, p3, c0, c1, c2, c3);
    }

    // Draw some text.
    {
        // Do a bunch of wacky math to figure out the text color.
        theta := cast(float) fmod_cycling(time*3, TAU);

        color: Vector4;
        color.x = cos(theta)*.5+.5;
        Clamp(*color.x, 0, 1);
        color.y = 1;
        color.z = sin(theta)*-.5+.5;
        Clamp(*color.z, 0, 1);
        color.w = 1;

        // Now, to draw the text:
        text := "Simp!";

        // We could just call Simp.draw_text to draw text! But we want to know the width
        // so that we can center the text, and to find the width, we have to do all the
        // text layout. So it makes sense just to draw the prepared text after that,
        // so there's a special routine, "draw_prepared_text", that draws the thing
        // you just prepared and got the width of.

        text_width := Simp.prepare_text(my_font, text);

        text_x := (window_width - text_width) / 2;
        text_y := window_height/2 + my_font.character_height/4;

        Simp.draw_prepared_text(my_font, text_x, text_y, color);
    }


    if image_test.width && image_test.height {
        // Draw the texture test, to make sure
        // it comes out right-side-up.

        Simp.set_shader_for_images(*image_test);
        Simp.immediate_begin();

        w := window_height/8.0;
        y0 := cast(float) window_height -vel.y;
        x0 := cast(float) vel.x; 

        Simp.immediate_quad(.{x0, y0-w}, .{x0+w, y0-w}, .{x0+w, y0}, .{x0, y0});
    }

    Simp.immediate_flush();
    Simp.swap_buffers(my_window);
}

my_init_fonts :: () {
    // So that we can load our font, set to path of running executable.
    // @Incomplete: Pack a default font into Simp.

    pixel_height := window_height / 24;

    // @Cleanup: Don't have path + name be separate.
    my_font = Simp.get_font_at_size(base_dir, "OpenSans-BoldItalic.ttf", pixel_height);
    assert(my_font != null);
}

base_dir: string;

my_font: *Simp.Dynamic_Font;

#if OS == .NN_SWITCH2 {
    Simp  :: #import "Simp"(render_api = .NVN);
    fs :: #import "Nintendo/fs";
} else {
    Simp  :: #import "Simp";
}
Input :: #import "Input";

#import "Window_Creation";

#import "Basic";
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

// #run {
//     #if OS == .WINDOWS {
//         WR :: #import "Windows_Resources";
//         WR.disable_runtime_console();
//     }
// }

// // To build for android: jai example.jai +Android/Toolchain -ext jpg:ttf [-x64]
// #if OS == .ANDROID  #import "Android"()(main);

// #run main();
