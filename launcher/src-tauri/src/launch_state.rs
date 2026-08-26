use std::{
    process::Child,
    sync::{
        atomic::{AtomicU8, Ordering},
        Arc,
    },
    thread,
};

use serde::Serialize;
use tauri::{AppHandle, Emitter};

const IDLE: u8 = 0;
const PREPARING: u8 = 1;
const RUNNING: u8 = 2;

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LaunchStatus {
    pub busy: bool,
    pub game_running: bool,
}

#[derive(Default)]
pub struct LaunchState {
    phase: Arc<AtomicU8>,
}

impl LaunchState {
    pub fn status(&self) -> LaunchStatus {
        status_from_phase(self.phase.load(Ordering::Acquire))
    }

    pub fn try_acquire(&self, app: AppHandle) -> Result<LaunchPermit, String> {
        self.phase
            .compare_exchange(IDLE, PREPARING, Ordering::AcqRel, Ordering::Acquire)
            .map_err(|_| "Подготовка или запуск игры уже выполняется".to_string())?;

        emit_status(&app, &self.phase);

        Ok(LaunchPermit {
            phase: Arc::clone(&self.phase),
            app,
            release_on_drop: true,
        })
    }
}

fn status_from_phase(phase: u8) -> LaunchStatus {
    LaunchStatus {
        busy: phase != IDLE,
        game_running: phase == RUNNING,
    }
}

fn emit_status(app: &AppHandle, phase: &AtomicU8) {
    let _ = app.emit(
        "launch-state",
        status_from_phase(phase.load(Ordering::Acquire)),
    );
}

pub struct LaunchPermit {
    phase: Arc<AtomicU8>,
    app: AppHandle,
    release_on_drop: bool,
}

impl LaunchPermit {
    pub fn track_game(mut self, mut child: Child) {
        self.phase.store(RUNNING, Ordering::Release);
        emit_status(&self.app, &self.phase);
        self.release_on_drop = false;

        let phase = Arc::clone(&self.phase);
        let app = self.app.clone();
        thread::spawn(move || {
            let _ = child.wait();
            phase.store(IDLE, Ordering::Release);
            emit_status(&app, &phase);
        });
    }
}

impl Drop for LaunchPermit {
    fn drop(&mut self) {
        if self.release_on_drop {
            self.phase.store(IDLE, Ordering::Release);
            emit_status(&self.app, &self.phase);
        }
    }
}
