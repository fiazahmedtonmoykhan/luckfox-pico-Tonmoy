import socket
import json
import threading
import os
import syslog

# -------- Constants / Global Variables --------
UDP_PORT = 50000
TCP_PORT = 60000
HANDSHAKE_MSG = "HELLO_LUCKFOX"
CONFIG_FILE_PATH = "/var/lib/enerzyz/device_config.json"  # config file path

# -------- Syslog Setup --------
syslog.openlog("device-configurator", syslog.LOG_PID)

def log_info(msg):
    syslog.syslog(syslog.LOG_INFO, msg)

def log_error(msg):
    syslog.syslog(syslog.LOG_ERR, msg)

def log_warn(msg):
    syslog.syslog(syslog.LOG_WARNING, msg)

# -------- Termination Flag --------
terminate_flag = threading.Event()

# -------- Device ID --------
def get_device_id():
    try:
        with open("/proc/cpuinfo", "r") as f:
            for line in f:
                if "Serial" in line or "serial" in line:
                    return line.split(":")[1].strip()
    except Exception as e:
        log_error(f"Failed to read CPU info: {e}")
    return "UNKNOWN_ID"

DEVICE_ID = get_device_id()
log_info(f"Device started with ID: {DEVICE_ID}")

# -------- TCP Server --------
def tcp_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("0.0.0.0", TCP_PORT))
    server.listen(1)
    server.settimeout(1)

    log_info(f"[TCP] Listening on port {TCP_PORT}")

    while not terminate_flag.is_set():
        try:
            conn, addr = server.accept()
        except socket.timeout:
            continue

        log_info(f"[TCP] Connection from {addr}")

        try:
            data = conn.recv(4096).decode()

            if data.startswith("CONFIG:"):
                json_data = data[len("CONFIG:"):]

                try:
                    config = json.loads(json_data)

                    tmp_file = CONFIG_FILE_PATH + ".tmp"
                    final_file = CONFIG_FILE_PATH

                    with open(tmp_file, "w") as f:
                        json.dump(config, f)

                    os.rename(tmp_file, final_file)

                    conn.send(b"OK")
                    log_info(f"[TCP] Config saved successfully to {CONFIG_FILE_PATH}")

                    # -------- Trigger termination --------
                    terminate_flag.set()

                except Exception as e:
                    conn.send(b"ERROR")
                    log_error(f"[TCP] JSON error: {e}")

            else:
                log_warn(f"[TCP] Unknown message: {data}")

        except Exception as e:
            log_error(f"[TCP] Connection error: {e}")

        conn.close()

    server.close()
    log_info("[TCP] Server stopped")

# -------- UDP Listener --------
def udp_listener():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("", UDP_PORT))
    sock.settimeout(1)

    log_info("[UDP] Waiting for handshake...")

    while not terminate_flag.is_set():
        try:
            data, addr = sock.recvfrom(2048)
        except socket.timeout:
            continue

        message = data.decode().strip()

        log_info(f"[UDP] Received from {addr}: {message}")

        if message == HANDSHAKE_MSG:
            reply = f"DEVICE_ID:{DEVICE_ID}"
            sock.sendto(reply.encode(), addr)
            log_info(f"[UDP] Handshake success → sent ID to {addr}")
        else:
            log_warn(f"[UDP] Unknown message: {message}")

    sock.close()
    log_info("[UDP] Listener stopped")

# -------- Main --------
if __name__ == "__main__":
    log_info("Starting device configurator service")

    # -------- Check if already configured --------
    if os.path.exists(CONFIG_FILE_PATH):
        log_info(f"Configuration file '{CONFIG_FILE_PATH}' exists. Exiting.")
    else:
        tcp_thread = threading.Thread(target=tcp_server)
        udp_thread = threading.Thread(target=udp_listener)

        tcp_thread.start()
        udp_thread.start()

        # Wait for termination (set after successful config)
        tcp_thread.join()
        udp_thread.join()

        log_info("Device configurator exited cleanly")
