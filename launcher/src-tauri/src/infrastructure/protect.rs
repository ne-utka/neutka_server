use crate::config::ConfigError;

const ENTROPY: &[u8] = b"com.springrp.launcher.session.v1";

pub fn protect(plain: &[u8]) -> Result<Vec<u8>, ConfigError> {
    dpapi_protect(plain)
}

pub fn unprotect(blob: &[u8]) -> Result<Vec<u8>, ConfigError> {
    dpapi_unprotect(blob)
}

#[cfg(windows)]
fn dpapi_protect(plain: &[u8]) -> Result<Vec<u8>, ConfigError> {
    use windows::core::w;
    use windows::Win32::Foundation::{LocalFree, HLOCAL};
    use windows::Win32::Security::Cryptography::{
        CryptProtectData, CRYPTPROTECT_UI_FORBIDDEN, CRYPT_INTEGER_BLOB,
    };

    if plain.is_empty() {
        return Err(ConfigError::Protect);
    }

    let mut entropy = ENTROPY.to_vec();
    let mut data_in = CRYPT_INTEGER_BLOB {
        cbData: u32::try_from(plain.len()).map_err(|_| ConfigError::Protect)?,
        pbData: plain.as_ptr() as *mut u8,
    };
    let entropy_blob = CRYPT_INTEGER_BLOB {
        cbData: u32::try_from(entropy.len()).map_err(|_| ConfigError::Protect)?,
        pbData: entropy.as_mut_ptr(),
    };
    let mut data_out = CRYPT_INTEGER_BLOB::default();

    unsafe {
        CryptProtectData(
            &mut data_in,
            w!("SpringRP launcher session"),
            Some(&entropy_blob),
            None,
            None,
            CRYPTPROTECT_UI_FORBIDDEN,
            &mut data_out,
        )
        .map_err(|_| ConfigError::Protect)?;

        let protected = std::slice::from_raw_parts(data_out.pbData, data_out.cbData as usize)
            .to_vec();
        let _ = LocalFree(Some(HLOCAL(data_out.pbData.cast())));
        Ok(protected)
    }
}

#[cfg(windows)]
fn dpapi_unprotect(blob: &[u8]) -> Result<Vec<u8>, ConfigError> {
    use windows::Win32::Foundation::{LocalFree, HLOCAL};
    use windows::Win32::Security::Cryptography::{
        CryptUnprotectData, CRYPTPROTECT_UI_FORBIDDEN, CRYPT_INTEGER_BLOB,
    };

    if blob.is_empty() {
        return Err(ConfigError::Unprotect);
    }

    let mut entropy = ENTROPY.to_vec();
    let mut data_in = CRYPT_INTEGER_BLOB {
        cbData: u32::try_from(blob.len()).map_err(|_| ConfigError::Unprotect)?,
        pbData: blob.as_ptr() as *mut u8,
    };
    let entropy_blob = CRYPT_INTEGER_BLOB {
        cbData: u32::try_from(entropy.len()).map_err(|_| ConfigError::Unprotect)?,
        pbData: entropy.as_mut_ptr(),
    };
    let mut data_out = CRYPT_INTEGER_BLOB::default();

    unsafe {
        CryptUnprotectData(
            &mut data_in,
            None,
            Some(&entropy_blob),
            None,
            None,
            CRYPTPROTECT_UI_FORBIDDEN,
            &mut data_out,
        )
        .map_err(|_| ConfigError::Unprotect)?;

        let plain = std::slice::from_raw_parts(data_out.pbData, data_out.cbData as usize)
            .to_vec();
        let _ = LocalFree(Some(HLOCAL(data_out.pbData.cast())));
        Ok(plain)
    }
}

#[cfg(not(windows))]
fn dpapi_protect(_: &[u8]) -> Result<Vec<u8>, ConfigError> {
    Err(ConfigError::Protect)
}

#[cfg(not(windows))]
fn dpapi_unprotect(_: &[u8]) -> Result<Vec<u8>, ConfigError> {
    Err(ConfigError::Unprotect)
}

#[cfg(all(test, windows))]
mod tests {
    use super::{protect, unprotect};

    #[test]
    fn dpapi_roundtrips_session_bytes() {
        let plain = b"kind = \"telegram\"\nplayer_name = \"Steve\"\n";
        let blob = protect(plain).expect("protect");
        assert_ne!(blob, plain);
        assert!(!blob.windows(plain.len()).any(|window| window == plain));
        let restored = unprotect(&blob).expect("unprotect");
        assert_eq!(restored, plain);
    }
}
