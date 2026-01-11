// Run "example.exe -server" to run as server, then run a second instance to connect as a client.
enet :: #import,file "../enet.jai";
#load("draw.jai");
#import "Basic";
#import "Math";
SERVER_ADDRESS :: "127.0.0.1";
SERVER_PORT :: 1234;
WAIT_FOR_PACKETS_MS :: 16;
MAX_CLIENTS :: 16;

main :: () {
    server: bool;
    args := get_command_line_arguments();
    for args {
        if it == "-server"
            server = true;
    }

    if !enet.initialize() {
        log_error("Failed to initialize enet");
        return;
    }
    defer enet.deinitialize();

    if server
        run_server();
    else
        run_client();
}

#import "Hash_Table";

table: Table(u32, Player_Definition);


run_server :: () {
    log("Running as SERVER");

    address: enet.Address;
    address.host = enet.HOST_ANY;
    address.port = SERVER_PORT;

    host, success := enet.host_create(*address, MAX_CLIENTS, 10, 0, 0);
    if !success {
        log_error("Failed to create server");
        return;
    }
    defer enet.host_destroy(host);

    log("Server started...");

    while true {
        event: enet.Event;
        while enet.host_service(host, *event, WAIT_FOR_PACKETS_MS) == .SUCCESS {
            sender_address := ifx event.peer != null then address_to_string(event.peer.address) else copy_string("UNKNOWN");
            defer free(sender_address);

            if event.type == {
                case .CONNECT;
                    log("Connected client % on connection %", sender_address, event.peer.connect_id);
                    pd:Player_Definition = New(Player_Definition);
                    pd.x = 0;
                    pd.y = 0;
                    table_add(*table, event.peer.connect_id, pd);

                case .RECEIVE;
                    msg:= New(Vector2);
                    memcpy(msg,event.packet.data,event.packet.data_length);
                    defer free(msg);
                    log("Server recieved message \"%\" on connection %", msg.x, event.peer.connect_id);
                    found, pd := table_find(*table, event.peer.connect_id);
                    pd.x= msg.x;
                    pd.y= msg.y;
                    table_set(*table,event.peer.connect_id,pd);
                    enet.packet_destroy(event.packet);

                case .DISCONNECT;
                    log("Disconnected client % on connection %", sender_address, event.peer.connect_id);

                case .DISCONNECT_TIMEOUT;
                    log("Disconnected (timeout) client % on connection %", sender_address, event.peer.connect_id);

                case;
                    log("Received event %", event.type);
            }
        }

        for * peer: host.peers {
            if peer.state == .CONNECTED {
                //found, msg := table_find(*table, peer.connect_id);

                //
                    msg:= table;
                    packet := enet.packet_create(*msg,.UNRELIABLE_FRAGMENT);
                    enet.peer_send(peer, 0, packet);
                //}
            }
        }
    }
}

Host::enet.Host;
Peer::enet.Peer;
Address :: enet.Address;
address : Address;

client: *Host;
connected:bool=false;

server: *Peer;
disconnect_countdown:int;
current_dt:float;
run_client :: () {
    log("Running as CLIENT");

    success:=false;
    client, success = enet.host_create(null, 1, 10, 0, 0);
    if !success {
        log_error("Failed to create client");
        return;
    }
    defer enet.host_destroy(client);

    address = enet.get_host_ip_address(SERVER_ADDRESS);
    address.port = SERVER_PORT;

    log("Connecting to server %:%", SERVER_ADDRESS, SERVER_PORT);
    server = enet.host_connect(client, address, 1, 5);

    disconnect_countdown = 1000;

    connected= false;

    vel =Vector2.{0.2,0.2};
    main_loop(client);  

}

vel:Vector2;

main_loop :: ( client : *Host) {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    // @Cleanup: This android+switch2 stuff is not good to have in our example program.
    #if OS == .NN_SWITCH2 {
        base_dir = copy_string(fs.mount_rom());
    } else {
        base_dir = ".";

        // :AndroidDefaultWorkingDirectory
        #if OS != .ANDROID {
            path := path_strip_filename(get_path_of_running_executable());
            set_working_directory(path);
        }
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    my_window = create_window(window_width, window_height, "A Window", wanted_msaa = WANTED_MSAA);


    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window(my_window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_width, window_height = Simp.get_render_dimensions(my_window);

    Simp.set_render_target(my_window, .LEFT_HANDED);

    success := Simp.texture_load_from_file(*image_test, tprint("%/image_test.jpg", base_dir));
    assert(success);

    my_init_fonts();

    quit := false;
    want_screenshot := false;
    last_draw=-1;
    while !quit {

        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.

            if it.window == my_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;

                if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .TOUCH;
                if it.touch_type == .PRESSED { // Touch screen to take a screenshot
                    want_screenshot = true;
                }

              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }

                // if it.key_pressed && it.key_code == #char " " {  // Press spacebar to take a screenshot.
                //     want_screenshot = true;
                // }
                if it.key_pressed && it.key_code == #char "W" {  // W moves up
                    vel += Vector2.{0,10};
                    print("moving");
                }
                if it.key_pressed && it.key_code == #char "A" {  // W moves up
                    vel += Vector2.{-10,0};
                    print("moving");
                }
                if it.key_pressed && it.key_code == #char "S" {  // W moves up
                    vel += Vector2.{0,-10};
                    print("moving");
                }
                if it.key_pressed && it.key_code == #char "D" {  // W moves up
                    vel += Vector2.{10,0};
                    print("moving");
                }

                // :AndroidLifeCycle :AndroidWindowSurfaceRecreation
              case .WINDOW;
                if it.window_event_type == {
                  case .MOVED_TO_BACKGROUND;
                    Simp.disable_window(it.window);
                    my_window = WT.INVALID_WINDOW;

                  case .MOVED_TO_FOREGROUND;
                    Simp.enable_window(it.window);
                    my_window = it.window;
                }
            }
        }

        run_client_network_events();

        time := seconds_since_init();
        delta : float64 = time - last_draw;
        current_dt = cast(float) delta;
        draw_one_frame();
        last_draw = time;

        if want_screenshot {
            screenshot_index += 1;

            // The Simp API for screenshots makes allowance for screenshots to occur
            // asynchronously. You call pixel_read_begin to start taking the screenshot,
            // and pixel_read_end to finish it and return the resulting bitmap (if it's
            // not ready yet, pixel_read_end will block until it is). If you want to know
            // whether the screenshot is done, you can call pixel_read_is_done().
            // Not all graphics APIs give us a way to do this asynchronously (for example,
            // OpenGL does not seem to), so you aren't guaranteed that this will be smooth,
            // but the API at least *provides a way* for it to be smooth if the backend permits.

            // Because this is a simple example, we just call _end immediately after _begin
            // to show the minimal code required to take a screenshot. To be asynchronous,
            // you would issue the read on one frame, then check whether it's done on each
            // subsequent frame, or else launch a thread to do this.
            async_read := Simp.pixel_read_begin(null, .RGBA8);
            bitmap     := Simp.pixel_read_end(async_read);

            filename := tprint("screenshot%.png\0", screenshot_index);

            #import "stb_image_write";
            stbi_write_png(filename.data, bitmap.width, bitmap.height, 4, bitmap.data.data, xx (bitmap.width * Simp.get_image_bytes_per_texel(bitmap.format)));  // Hardcoded to 4 channels because we know we requested .BGRA8 above.

            want_screenshot = false;

            Simp.deinit(*bitmap);
        }
        
        // sleep_milliseconds (10);
        reset_temporary_storage();
    }
}

run_client_network_events :: (){
    event: enet.Event;
        if enet.host_service(client, *event, WAIT_FOR_PACKETS_MS) == .SUCCESS {
            if event.type == {
                case .CONNECT;
                    log("Connected to server via connection %", event.peer.connect_id);
                    connected = true;

                case .RECEIVE;
                    // if (event.packet.data_length == size_of(Player_Definition))
                    // {
                        tab:Table(u32,*Player_Definition);
                        memcpy(*tab,event.packet.data,event.packet.data_length);
                        found,pd := table_find(*tab,event.peer.connect_id);
                        if(found){
                            log("Client pos is % % on id: %", pd.x, pd.y,event.peer.connect_id);
                        }
                        defer free(pd);    
                        
                    // }else{
                    //     msg: string = .{event.packet.data_length, event.packet.data};
                    //     log("Client recieved message \"%\" on connection %", msg, event.peer.connect_id);
                    //     defer free(msg);
                    // }
                    enet.packet_destroy(event.packet);



                case .DISCONNECT;
                    log("Connection % disconnected", event.peer.connect_id);
                    return ;

                case .DISCONNECT_TIMEOUT;
                    log("Connection % disconnected (timeout)", event.peer.connect_id);
                    return ;

                case;
                    log("Received event %", event.type);
            }
        }

        if connected {

            another_msg:Vector2 = vel;
            another_packet := enet.packet_create(*another_msg,.UNRELIABLE_FRAGMENT);
            enet.peer_send(server, 0, another_packet);

            // if disconnect_countdown > 0 {
            //     msg := sprint("Client on connection % will disconnect in %", server.connect_id, disconnect_countdown);
            //     defer free(msg);
            //     packet := enet.packet_create(msg.data, msg.count, .UNRELIABLE_FRAGMENT);
            //     enet.peer_send(server, 0, packet);
            // } else {
            //     enet.peer_disconnect(server, 0);
            // }
            disconnect_countdown -= 1;
        }
}
address_to_string :: (address : enet.Address) -> string {
    Socket :: #import "Socket";
    addr : Socket.sockaddr_in6;
    addr.sin6_port = address.port;
    addr.sin6_addr = address.host;
    addr.sin6_scope_id = address.sin6_scope_id;
    return Socket.to_string(addr);
}



Player_Definition ::struct{
    x :float;
    y :float;
}