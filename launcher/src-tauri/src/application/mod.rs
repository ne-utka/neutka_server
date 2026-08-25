use std::path::Path;

use crate::domain::ArchitectureStatus;

pub struct ArchitectureService;

impl ArchitectureService {
    pub fn status(helper_path: &Path) -> ArchitectureStatus {
        ArchitectureStatus::inspect(helper_path)
    }
}
