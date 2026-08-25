//! Подбор объёма кучи под машину игрока и флаги запуска JVM.

/// Меньше двух гигабайт сборка с модами не запускается стабильно.
const MIN_GB: u32 = 2;
/// Клиенту Minecraft больше не помогает: растёт пауза сборки мусора.
const MAX_GB: u32 = 16;
/// Оставляем системе, браузеру и голосовому чату.
const RESERVED_FOR_SYSTEM_GB: u32 = 4;
const STEPS: &[u32] = &[2, 3, 4, 5, 6, 8, 10, 12, 16];

#[derive(Debug, Clone)]
pub struct MemoryProfile {
    pub total_gb: u32,
    pub options: Vec<u32>,
    pub recommended_gb: u32,
}

impl MemoryProfile {
    /// Приводит сохранённый выбор к тому, что машина потянет: конфиг мог
    /// приехать с другого компьютера.
    pub fn clamp(&self, requested_gb: u32) -> u32 {
        if self.options.contains(&requested_gb) {
            return requested_gb;
        }
        self.options
            .iter()
            .copied()
            .filter(|value| *value <= requested_gb)
            .max()
            .unwrap_or_else(|| self.options.first().copied().unwrap_or(MIN_GB))
    }

    pub fn allows(&self, requested_gb: u32) -> bool {
        self.options.contains(&requested_gb)
    }
}

pub fn profile() -> MemoryProfile {
    let total_gb = total_physical_gb().unwrap_or(8);
    let ceiling = ceiling_gb(total_gb);

    let mut options: Vec<u32> = STEPS
        .iter()
        .copied()
        .filter(|value| *value <= ceiling)
        .collect();
    if options.is_empty() {
        options.push(MIN_GB);
    }

    MemoryProfile {
        recommended_gb: recommended_gb(total_gb, &options),
        total_gb,
        options,
    }
}

fn ceiling_gb(total_gb: u32) -> u32 {
    let by_share = total_gb * 3 / 4;
    let by_reserve = total_gb.saturating_sub(RESERVED_FOR_SYSTEM_GB);
    by_share.min(by_reserve).clamp(MIN_GB, MAX_GB)
}

fn recommended_gb(total_gb: u32, options: &[u32]) -> u32 {
    let target = match total_gb {
        0..=6 => 2,
        7..=10 => 4,
        11..=20 => 6,
        _ => 8,
    };
    options
        .iter()
        .copied()
        .filter(|value| *value <= target)
        .max()
        .unwrap_or(MIN_GB)
}

/// Аргументы JVM для клиента: размер кучи и настройка G1.
///
/// `-Xms` равен `-Xmx` намеренно: иначе куча растёт уже во время игры, и
/// каждое расширение даёт полную сборку мусора с заметным рывком.
pub fn performance_arguments(max_memory_mb: u32) -> Vec<String> {
    vec![
        format!("-Xmx{max_memory_mb}M"),
        format!("-Xms{max_memory_mb}M"),
        "-XX:+UnlockExperimentalVMOptions".into(),
        "-XX:+UseG1GC".into(),
        format!("-XX:G1HeapRegionSize={}M", region_size_mb(max_memory_mb)),
        "-XX:G1NewSizePercent=20".into(),
        "-XX:G1ReservePercent=20".into(),
        "-XX:MaxGCPauseMillis=50".into(),
        "-XX:+ParallelRefProcEnabled".into(),
        "-XX:+PerfDisableSharedMem".into(),
        "-XX:-OmitStackTraceInFastThrow".into(),
    ]
}

/// Размер региона выбирается так, чтобы куча делилась примерно на 512 частей:
/// у G1 слишком крупные регионы на маленькой куче ломают смешанные сборки.
fn region_size_mb(max_memory_mb: u32) -> u32 {
    match max_memory_mb {
        0..=4096 => 8,
        4097..=8192 => 16,
        _ => 32,
    }
}

#[cfg(windows)]
fn total_physical_gb() -> Option<u32> {
    use windows::Win32::System::SystemInformation::{GlobalMemoryStatusEx, MEMORYSTATUSEX};

    let mut status = MEMORYSTATUSEX {
        dwLength: std::mem::size_of::<MEMORYSTATUSEX>() as u32,
        ..Default::default()
    };
    unsafe { GlobalMemoryStatusEx(&mut status) }.ok()?;

    let gigabyte = 1024_u64 * 1024 * 1024;
    let rounded = (status.ullTotalPhys + gigabyte / 2) / gigabyte;
    u32::try_from(rounded).ok().filter(|value| *value > 0)
}

#[cfg(not(windows))]
fn total_physical_gb() -> Option<u32> {
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn weak_machines_keep_headroom_for_the_system() {
        assert_eq!(ceiling_gb(8), 4);
        assert_eq!(ceiling_gb(6), 2);
        assert_eq!(ceiling_gb(4), 2);
    }

    #[test]
    fn large_machines_stop_where_the_client_stops_benefiting() {
        assert_eq!(ceiling_gb(32), MAX_GB);
        assert_eq!(ceiling_gb(64), MAX_GB);
    }

    #[test]
    fn recommendation_stays_inside_the_offered_steps() {
        for total in [4_u32, 8, 12, 16, 32, 64] {
            let profile = MemoryProfile {
                total_gb: total,
                options: STEPS
                    .iter()
                    .copied()
                    .filter(|value| *value <= ceiling_gb(total))
                    .collect(),
                recommended_gb: 0,
            };
            let recommended = recommended_gb(total, &profile.options);
            assert!(
                profile.options.contains(&recommended),
                "{total} ГБ: рекомендация {recommended} вне списка {:?}",
                profile.options
            );
        }
    }

    #[test]
    fn foreign_configuration_is_pulled_down_to_a_supported_step() {
        let profile = MemoryProfile {
            total_gb: 8,
            options: vec![2, 3, 4],
            recommended_gb: 4,
        };
        assert_eq!(profile.clamp(12), 4);
        assert_eq!(profile.clamp(3), 3);
        assert_eq!(profile.clamp(1), 2);
    }

    #[test]
    fn heap_size_drives_the_region_size() {
        assert_eq!(region_size_mb(2048), 8);
        assert_eq!(region_size_mb(4096), 8);
        assert_eq!(region_size_mb(6144), 16);
        assert_eq!(region_size_mb(16384), 32);
    }

    #[test]
    fn initial_heap_matches_the_maximum() {
        let arguments = performance_arguments(4096);
        assert!(arguments.contains(&"-Xmx4096M".to_string()));
        assert!(arguments.contains(&"-Xms4096M".to_string()));
    }
}
