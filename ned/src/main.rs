use niri_ipc::{socket::Socket, Request};
use regex::Regex;
use std::{env, process::Stdio, sync::Arc};
use tokio::{io::AsyncWriteExt, process::Command};

struct Listener {
    matcher: Regex,
    command: String,
}

fn parse_args(args: &[String]) -> anyhow::Result<Vec<Listener>> {
    if args.len() < 2 {
        anyhow::bail!("usage: ned REGEX COMMAND [REGEX COMMAND ...]");
    }
    if args.len() % 2 != 0 {
        anyhow::bail!("Expected pairs of REGEX COMMAND, got odd number of arguments");
    }
    let mut listeners = Vec::new();
    let iter = args.chunks_exact(2);
    for pair in iter {
        let regex = Regex::new(&pair[0])?;
        let command = pair[1].clone();
        listeners.push(Listener { matcher: regex, command });
    }
    Ok(listeners)
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args: Vec<String> = env::args().skip(1).collect();
    let listeners = Arc::new(parse_args(&args)?);
    let mut socket = Socket::connect()?;
    socket
        .send(Request::EventStream)?
        .map_err(|error| anyhow::anyhow!("ERR - Unable to connect: {error}"))?;

    let mut read_event = socket.read_events();

    loop {
        let event = match read_event() {
            Ok(event) => event,
            Err(error) => {
                eprintln!("ERR - Failed to read event: {error}");
                continue;
            }
        };

        let json = serde_json::to_value(&event)?;
        let event_name = match json.as_object().and_then(|object| object.keys().next()) {
            Some(name) => name.clone(),
            None => {
                eprintln!("ERR - Expected JSON object with a single key: {json}");
                continue;
            }
        };

        let payload = serde_json::to_vec(&json)?;

        for listener in listeners.iter() {
            if listener.matcher.is_match(&event_name) {
                let command = listener.command.clone();
                let payload = payload.clone();
                tokio::spawn(async move {
                    let mut command = if command.contains(',') {
                        let mut parts = command.split(',').map(|s| s.trim());
                        if let Some(prog) = parts.next() {
                            let mut c = Command::new(prog);
                            for arg in parts {
                                c.arg(arg);
                            }
                            c
                        } else {
                            eprintln!("invalid command list: `{command}`");
                            return;
                        }
                    } else if ! command.contains(' ') {
                        Command::new(command)
                    } else {
                        let mut c = Command::new("sh");
                        c.arg("-c").arg(command);
                        c
                    };

                    command
                        .stdin(Stdio::piped())
                        .stdout(Stdio::inherit())
                        .stderr(Stdio::inherit());

                    let mut child = match command.spawn() {
                        Ok(c) => c,
                        Err(e) => {
                            eprintln!("ERR - Failed to spawn command: {e}");
                            return;
                        }
                    };

                    if let Some(mut stdin) = child.stdin.take() {
                        if let Err(e) = stdin.write_all(&payload).await {
                            eprintln!("ERR - Failed to write to command stdin: {e}");
                        }
                        let _ = stdin.write_all(b"\n").await;
                    }

                    if let Err(e) = child.wait().await {
                        eprintln!("ERR - Command execution failed: {e}");
                    }
                });
            }
        }
    }
}
