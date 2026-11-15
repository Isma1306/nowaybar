package main

import "core:encoding/json"
import "core:log"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:sys/linux"


Workspace_info :: struct {
	id:              int,
	name:            string,
	monitor:         string,
	monitorID:       int,
	windows:         int,
	hasfullscreen:   bool,
	lastwindow:      string,
	lastwindowtitle: string,
	ispersistent:    bool,
	tiledLayout:     string,
}

get_socket :: proc(filename: string) -> (string, bool) {
	xdg, ok := os.lookup_env("XDG_RUNTIME_DIR", context.temp_allocator)
	if !ok {
		log.error("xdg not set")
		return "", false
	}

	hyprland_instance, ok2 := os.lookup_env("HYPRLAND_INSTANCE_SIGNATURE", context.temp_allocator)
	if !ok2 {
		log.error("hyprland_instance not set")
		return "", false
	}
	return strings.concatenate(
			{xdg, "/hypr/", hyprland_instance, filename},
			context.temp_allocator,
		),
		true
}

connect_hypr :: proc(socket: string) -> linux.Fd {
	socket2, _ := get_socket(socket)
	fd_socket, err_sock := linux.socket(.UNIX, .STREAM, {}, .HOPOPT)
	if err_sock != .NONE {
		log.error("linux.socket: ", err_sock)
		os.exit(1)
	}
	addr := linux.Sock_Addr_Un {
		sun_family = .UNIX,
	}
	copy(addr.sun_path[:], socket2)
	err_conn := linux.connect(fd_socket, &addr)
	if err_conn != .NONE {
		log.error("linux.connect: ", err_conn)
		os.exit(1)
	}
	return fd_socket
}

set_workspaces :: proc(state: ^State) {
	workspace_list := []Workspace_info{}
	raw_bytes, ok := req_hypr("j/workspaces")
	if (!ok) {
		log.error("req_hypr")
		os.exit(1)
	}
	err := json.unmarshal(raw_bytes, &workspace_list, allocator = context.allocator)
	if err != nil {
		log.error("json.unmarshal: ", err)
		os.exit(1)
	}
	slice.sort_by(workspace_list, proc(a, b: Workspace_info) -> bool {return a.id < b.id})
	state.workspace_list = workspace_list
}

set_active_workspace :: proc(state: ^State) {
	active_workspace := Workspace_info{}
	raw_bytes, ok := req_hypr("j/activeworkspace")
	if (!ok) {
		log.error("req_hypr")
		os.exit(1)
	}
	err := json.unmarshal(raw_bytes, &active_workspace, allocator = context.temp_allocator)
	if err != nil {
		log.error("json.unmarshal: ", err)
		os.exit(1)
	}
	state.active_workspace = active_workspace.id
}


req_hypr :: proc(command: string) -> ([]u8, bool) {
	fd := connect_hypr("/.socket.sock")
	log.infof("command: %s", command)
	buf_com := transmute([]u8)command
	_, err := linux.write(fd, buf_com)
	if (err != .NONE) {
		log.error("linux.write: ", err)
		return []u8{}, false
	}
	buf := [4096]u8{}
	all_bytes := make([dynamic]u8, context.temp_allocator)


	for {
		n, err_read := linux.read(fd, buf[:])
		if err_read != .NONE {
			log.error("linux.read: ", err_read)
			os.exit(1)
		}
		if (n == 0) {
			linux.close(fd)
			break
		}
		append(&all_bytes, ..buf[:n])
	}
	return all_bytes[:], true
}

handle_hyprland :: proc(fd: linux.Fd, state: ^State) -> bool {

	buf := [4096]u8{}

	n, err_read := linux.read(fd, buf[:])
	if err_read != .NONE {
		log.error("linux.read: ", err_read)
		os.exit(1)
	}
	if (n == 0) {
		log.error("linux.read: n == 0")
		os.exit(1)
	}
	changed := false
	msg_lines := strings.split_lines(string(buf[:n]), context.temp_allocator)
	for line in msg_lines {
		splitted := strings.split(line, ">>", context.temp_allocator)
		if (len(splitted) == 2) {

			if (splitted[0] == "workspacev2") {
				parts := strings.index_byte(splitted[1], ',')
				if (parts != -1) {
					active_workspace, ok := strconv.parse_int(splitted[1][:parts])
					if (!ok) {
						log.error("strconv.parse_int failed")
					} else {
						state.active_workspace = active_workspace
						changed = true
					}
				}
			}
		}
	}
	free_all(context.temp_allocator)

	return changed
}
