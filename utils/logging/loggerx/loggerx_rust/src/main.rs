use chrono::Utc;
use std::collections::HashMap;
use std::env;
use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::path::Path;
use std::process::{Command, Stdio};

fn parent_pid() -> u32 {
    unsafe { libc::getppid() as u32 }
}

const TIME_FORMAT: &str = "%Y-%m-%dT%H-%M-%SZ";

#[derive(Clone, Copy)]
struct LevelSpec {
    color: &'static str,
}

fn level_table() -> HashMap<&'static str, LevelSpec> {
    HashMap::from([
        ("EMERGENCY", LevelSpec { color: "\x1b[01;30;41m" }),
        ("ALERT", LevelSpec { color: "\x1b[01;31;43m" }),
        ("CRITICAL", LevelSpec { color: "\x1b[01;30;48:5:208m" }),
        ("ERROR", LevelSpec { color: "\x1b[01;31m" }),
        ("WARNING", LevelSpec { color: "\x1b[01;33m" }),
        ("NOTICE", LevelSpec { color: "\x1b[01;95m" }),
        ("INFO", LevelSpec { color: "\x1b[01;39m" }),
        ("DEBUG", LevelSpec { color: "\x1b[01;94m" }),
        ("SUCCESS", LevelSpec { color: "\x1b[01;32m" }),
    ])
}

fn numeric_level_map() -> HashMap<&'static str, &'static str> {
    HashMap::from([
        ("0", "EMERGENCY"),
        ("1", "ALERT"),
        ("2", "CRITICAL"),
        ("3", "ERROR"),
        ("4", "WARNING"),
        ("5", "NOTICE"),
        ("6", "INFO"),
        ("7", "DEBUG"),
        ("9", "SUCCESS"),
    ])
}

fn command_name() -> String {
    env::args()
        .next()
        .and_then(|v| Path::new(&v).file_name().map(|s| s.to_string_lossy().to_string()))
        .filter(|v| !v.trim().is_empty())
        .unwrap_or_else(|| "loggerx_rust".to_string())
}

fn usage() {
    let cmd = command_name();
    println!("{} - syslog-style logger for improved developer experience (DX)", cmd);
    println!();
    println!("Writes colored output to stdout and sends raw messages to syslog via logger.");
    println!("Supports multi-line messages and dynamic application naming.");
    println!();
    println!("Usage:");
    println!("{} <LEVEL> <MESSAGE...>", cmd);
    println!();
    println!("Levels:");
    println!("0/EMERGENCY    3/ERROR        6/INFO");
    println!("1/ALERT        4/WARNING      7/DEBUG");
    println!("2/CRITICAL     5/NOTICE       9/SUCCESS");
    println!();
    println!("Environment Variables:");
    println!("APP_NAME       Optional. Overrides inferred application name in logs.");
    println!("APP_PID        Optional. Overrides inferred PID in logs (e.g., for et/rc forwarding).");
    println!("LOG_TO_FILE    If set to \"true\", also appends formatted output to LOG_FILE.");
    println!("LOG_FILE       Path to log file when LOG_TO_FILE is enabled.");
    println!("SYSLOG         If set to \"true\", sends output to syslog as well as stdout.");
    println!();
    println!("Examples:");
    println!("{} INFO \"Service started\"", cmd);
    println!("export APP_NAME=myapp; {} WARNING \"Disk usage high\"", cmd);
}

fn normalize_level(value: &str) -> Option<String> {
    if let Some(mapped) = numeric_level_map().get(value) {
        return Some((*mapped).to_string());
    }
    if level_table().contains_key(value) {
        return Some(value.to_string());
    }
    None
}

fn read_proc_file(path: &str) -> Option<Vec<u8>> {
    fs::read(path).ok()
}

fn infer_app_name() -> String {
    if let Ok(name) = env::var("APP_NAME") {
        let trimmed = name.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }

    let ppid = parent_pid();
    let env_path = format!("/proc/{}/task/{}/environ", ppid, ppid);
    if let Some(bytes) = read_proc_file(&env_path) {
        for entry in bytes.split(|b| *b == 0) {
            if entry.starts_with(b"_=") {
                let underscore = String::from_utf8_lossy(&entry[2..]).trim().to_string();
                if !underscore.is_empty() {
                    let base = Path::new(&underscore)
                        .file_name()
                        .map(|v| v.to_string_lossy().to_string())
                        .unwrap_or_default();
                    if !base.is_empty() {
                        if base == "loggerx" || base == "loggerx_rust" {
                            break;
                        }
                        return base;
                    }
                }
                break;
            }
        }
    }

    let mut name = command_name();
    if name.trim().is_empty() {
        name = "loggerx_rust".to_string();
    }

    if name == "loggerx" || name == "loggerx_rust" {
        let cmdline_path = format!("/proc/{}/task/{}/cmdline", ppid, ppid);
        if let Some(bytes) = read_proc_file(&cmdline_path) {
            let first = bytes
                .split(|b| *b == 0)
                .next()
                .map(|v| String::from_utf8_lossy(v).trim().to_string())
                .unwrap_or_default();
            if !first.is_empty() {
                if let Some(base) = Path::new(&first).file_name() {
                    let inferred = base.to_string_lossy().to_string();
                    if !inferred.trim().is_empty() {
                        name = inferred;
                    }
                }
            }
        }
    }

    name
}

fn normalize_raw_message(value: &str) -> String {
    if value.is_empty() {
        return String::new();
    }

    let mut lines: Vec<String> = value.split('\n').map(|v| v.to_string()).collect();
    for line in lines.iter_mut().skip(1) {
        *line = format!("    {}", line.trim_start_matches(|c| c == ' ' || c == '\t'));
    }
    lines.join("\n")
}

fn send_syslog(raw: &str) -> io::Result<()> {
    let mut child = Command::new("logger")
        .stdin(Stdio::piped())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .spawn()?;

    if let Some(stdin) = child.stdin.as_mut() {
        stdin.write_all(raw.as_bytes())?;
    }

    let status = child.wait()?;
    if status.success() {
        Ok(())
    } else {
        Err(io::Error::new(io::ErrorKind::Other, "logger exited non-zero"))
    }
}

fn append_file(path: &str, text: &str) -> io::Result<()> {
    let mut file = OpenOptions::new().create(true).append(true).open(path)?;
    writeln!(file, "{}", text)
}

fn current_hostname() -> String {
    let hostname = env::var("HOSTNAME").unwrap_or_default();
    if !hostname.trim().is_empty() {
        return hostname;
    }

    if let Ok(bytes) = fs::read("/proc/sys/kernel/hostname") {
        let h = String::from_utf8_lossy(&bytes).trim().to_string();
        if !h.is_empty() {
            return h;
        }
    }

    String::new()
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 && (args[1] == "-h" || args[1] == "--help") {
        usage();
        return;
    }

    if args.len() < 3 {
        usage();
        std::process::exit(1);
    }

    let original_level = args[1].clone();
    let mut level_valid = true;
    let level = match normalize_level(&original_level) {
        Some(v) => v,
        None => {
            level_valid = false;
            "ERROR".to_string()
        }
    };

    let table = level_table();
    let spec = match table.get(level.as_str()) {
        Some(v) => *v,
        None => {
            eprintln!("Invalid log level: '{}'!", level);
            std::process::exit(1);
        }
    };

    let mut message = if level_valid {
        args[2..].join(" ")
    } else {
        format!("Invalid log level: '{}'!", original_level.trim())
    };

    let trimmed_lines: Vec<String> = message
        .split('\n')
        .map(|line| line.trim_start_matches(' ').to_string())
        .collect();
    message = trimmed_lines.join("\n");

    let timestamp = Utc::now().format(TIME_FORMAT).to_string();
    let hostname = current_hostname();
    let app_name = infer_app_name();
    let app_pid = env::var("APP_PID").unwrap_or_else(|_| format!("[{}] ", parent_pid()));

    let rendered_level = format!("{}{}\x1b[0m", spec.color, level);
    let mut formatted = format!(
        "{} {} {}{}{}: {}",
        timestamp, hostname, app_name, app_pid, rendered_level, message
    );
    while formatted.ends_with('\n') {
        formatted.pop();
    }

    let prefix = format!("{} {} {}{}{}:", timestamp, hostname, app_name, app_pid, level);
    let indent = " ".repeat(prefix.chars().count() + 1);
    let log_line = formatted.replace('\n', &format!("\n{}", indent));

    if env::var("LOG_TO_FILE").unwrap_or_default() == "true" {
        println!("{}", log_line);
        if let Ok(path) = env::var("LOG_FILE") {
            if !path.trim().is_empty() {
                let _ = append_file(&path, &log_line);
            }
        }
    }

    let raw = format!("{}{}{}: {}", app_name, app_pid, level, normalize_raw_message(&message));
    if env::var("SYSLOG").unwrap_or_default() == "true" {
        let _ = send_syslog(&raw);
    }

    println!("{}", log_line);

    if !level_valid {
        std::process::exit(1);
    }
}
