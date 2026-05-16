use std::process::Stdio;
use std::os::unix::process::CommandExt;
use std::fs::File;
use std::path::PathBuf;
use nix::unistd::{setpgid, Pid};
use nix::sys::signal::{kill, Signal};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ProcessError {
    #[error("Failed to spawn process: {0}")]
    Spawn(#[from] std::io::Error),
    #[error("Failed to open log file {0}: {1}")]
    Log(PathBuf, std::io::Error),
    #[error("Signal error: {0}")]
    Signal(#[from] nix::Error),
}

pub struct ProcessHandle {
    pub child: std::process::Child,
}

impl ProcessHandle {
    pub fn spawn(
        command: &[String],
        cwd: Option<&PathBuf>,
        env: &std::collections::HashMap<String, String>,
        stdout_log: Option<&PathBuf>,
        stderr_log: Option<&PathBuf>,
    ) -> Result<Self, ProcessError> {
        if command.is_empty() {
            return Err(ProcessError::Spawn(std::io::Error::new(
                std::io::ErrorKind::InvalidInput,
                "Empty command",
            )));
        }

        let mut cmd = std::process::Command::new(&command[0]);
        if command.len() > 1 {
            cmd.args(&command[1..]);
        }

        if let Some(dir) = cwd {
            cmd.current_dir(dir);
        }
        cmd.envs(env);

        // Pre-exec hook to put the process in its own process group
        unsafe {
            cmd.pre_exec(|| {
                setpgid(Pid::from_raw(0), Pid::from_raw(0))
                    .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))?;
                Ok(())
            });
        }

        if let Some(log_path) = stdout_log {
            if let Some(parent) = log_path.parent() {
                let _ = std::fs::create_dir_all(parent);
            }
            let file = File::options().create(true).append(true).open(log_path)
                .map_err(|e| ProcessError::Log(log_path.to_path_buf(), e))?;
            cmd.stdout(Stdio::from(file));
        } else {
            cmd.stdout(Stdio::null());
        }

        if let Some(log_path) = stderr_log {
            if let Some(parent) = log_path.parent() {
                let _ = std::fs::create_dir_all(parent);
            }
            let file = File::options().create(true).append(true).open(log_path)
                .map_err(|e| ProcessError::Log(log_path.to_path_buf(), e))?;
            cmd.stderr(Stdio::from(file));
        } else {
            cmd.stderr(Stdio::null());
        }

        let child = cmd.spawn()?;
        Ok(Self { child })
    }

    pub fn pid(&self) -> u32 {
        self.child.id()
    }

    pub fn stop(&self) -> Result<(), ProcessError> {
        // Send SIGTERM to process group
        let pgid = Pid::from_raw(self.pid() as i32);
        let _ = kill(Pid::from_raw(-pgid.as_raw()), Signal::SIGTERM);
        Ok(())
    }

    pub fn kill(&mut self) -> Result<(), ProcessError> {
        let pgid = Pid::from_raw(self.pid() as i32);
        let _ = kill(Pid::from_raw(-pgid.as_raw()), Signal::SIGKILL);
        self.child.kill().map_err(ProcessError::Spawn)?;
        Ok(())
    }
}
