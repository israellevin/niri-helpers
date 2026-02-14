use niri_ipc::{socket::Socket, Request};
use regex::Regex;
use std::{
    env,
    process::Stdio,
    sync::Arc,
    time::Duration,
};
use tokio::{
    io::AsyncWriteExt,
    process::Command,
    sync::Semaphore,
    time::timeout,
};

const MAX_CONCURRENT_TASKS: usize = 8;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(5);

enum PreparedCommand {
    Exec {
        program: String,
        args: Vec<String>,
    },
    Shell {
        command: String,
    },
}

struct Listener {
    matcher: Regex,
    command: Arc<PreparedCommand>,
}

fn prepare_command(command: &str) -> anyhow::Result<PreparedCommand> {
    if command.contains(',') {
        let parts: Vec<_> = command.split(',').map(|s| s.trim()).collect();
        if parts.is_empty() || parts[0].is_empty() || parts.iter().any(|s| s.contains(' ')) {
            anyhow::bail!("invalid command list: `{command}`");
        }
        Ok(PreparedCommand::Exec {
            program: parts[0].to_string(),
            args: parts[1..].iter().map(|s| s.to_string()).collect(),
        })
    } else if !command.contains(' ') {
        Ok(PreparedCommand::Exec {
            program: command.to_string(),
            args: Vec::new(),
        })
    } else {
        Ok(PreparedCommand::Shell {
            command: command.to_string(),
        })
    }
}

fn parse_args(args: &[String]) -> anyhow::Result<Vec<Listener>> {
    if args.len() < 2 {
        anyhow::bail!("usage: ned REGEX COMMAND [REGEX COMMAND ...]");
    }
    if args.len() % 2 != 0 {
        anyhow::bail!("Expected pairs of REGEX COMMAND, got odd number of arguments");
    }

    let mut listeners = Vec::new();

    for pair in args.chunks_exact(2) {
        let matcher = Regex::new(&pair[0])?;
        let command = Arc::new(prepare_command(&pair[1])?);
        listeners.push(Listener { matcher, command });
    }

    Ok(listeners)
}

async fn run_command(
    prepared: Arc<PreparedCommand>,
    payload: Vec<u8>,
) -> anyhow::Result<()> {
    let mut command = match &*prepared {
        PreparedCommand::Exec { program, args } => {
            let mut c = Command::new(program);
            c.args(args);
            c
        }
        PreparedCommand::Shell { command } => {
            let mut c = Command::new("sh");
            c.arg("-c").arg(command);
            c
        }
    };

    command
        .stdin(Stdio::piped())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());

    let mut child = command.spawn()?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(&payload).await?;
        stdin.write_all(b"\n").await?;
    }

    child.wait().await?;
    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args: Vec<String> = env::args().skip(1).collect();
    let listeners = Arc::new(parse_args(&args)?);

    let semaphore = Arc::new(Semaphore::new(MAX_CONCURRENT_TASKS));

    let mut socket = Socket::connect()?;
    socket
        .send(Request::EventStream)?
        .map_err(|e| anyhow::anyhow!("ERR - Unable to connect: {e}"))?;

    let mut read_event = socket.read_events();

    loop {
        let event = match read_event() {
            Ok(event) => event,
            Err(e) => {
                eprintln!("ERR - Failed to read event: {e}");
                continue;
            }
        };

        let json = serde_json::to_value(&event)?;
        let event_name = match json.as_object().and_then(|o| o.keys().next()) {
            Some(name) => name.clone(),
            None => {
                eprintln!("ERR - Expected JSON object with single key: {json}");
                continue;
            }
        };

        let payload = serde_json::to_vec(&json)?;

        for listener in listeners.iter() {
            if !listener.matcher.is_match(&event_name) {
                continue;
            }

            let permit = match semaphore.clone().try_acquire_owned() {
                Ok(p) => p,
                Err(_) => {
                    eprintln!("WARN - task limit reached, dropping event `{event_name}`");
                    continue;
                }
            };

            let command = listener.command.clone();
            let payload = payload.clone();

            tokio::spawn(async move {
                let _permit = permit; // released on drop

                let result = timeout(
                    COMMAND_TIMEOUT,
                    run_command(command, payload),
                )
                .await;

                match result {
                    Ok(Ok(())) => {}
                    Ok(Err(e)) => {
                        eprintln!("ERR - Command failed: {e}");
                    }
                    Err(_) => {
                        eprintln!("ERR - Command timed out");
                    }
                }
            });
        }
    }
}
