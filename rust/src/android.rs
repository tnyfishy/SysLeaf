use crate::categories;
use crate::error::{CoreError, Result};
use crate::model::AppInfo;
use base64::Engine;
use jni::objects::{GlobalRef, JByteArray, JObject, JObjectArray, JString, JValue};
use jni::{JNIEnv, JavaVM};
use std::sync::{Mutex, OnceLock};

static VM: OnceLock<JavaVM> = OnceLock::new();
static CONTEXT: Mutex<Option<GlobalRef>> = Mutex::new(None);

// Android bootstrap only hands an Application context to Rust. All package,
// permission, icon and root logic stays in Rust; no MethodChannel is involved.
#[no_mangle]
pub extern "system" fn Java_dev_sysleaf_sysleaf_MainActivity_nativeInitialize(
    env: JNIEnv,
    _class: JObject,
    context: JObject,
) {
    if let (Ok(vm), Ok(global)) = (env.get_java_vm(), env.new_global_ref(context)) {
        let _ = VM.set(vm);
        if let Ok(mut value) = CONTEXT.lock() {
            *value = Some(global);
        }
    }
}

fn with_context<T>(f: impl FnOnce(&mut JNIEnv, &JObject) -> Result<T>) -> Result<T> {
    let vm = VM.get().ok_or_else(|| {
        CoreError::new("ANDROID_NOT_READY", "Application context not initialized.")
    })?;
    let context = CONTEXT
        .lock()
        .map_err(|_| CoreError::new("ANDROID_NOT_READY", "Context lock unavailable."))?
        .clone()
        .ok_or_else(|| CoreError::new("ANDROID_NOT_READY", "No Application context."))?;
    let mut env = vm.attach_current_thread()?;
    let result = f(&mut env, context.as_obj());
    if env.exception_check().unwrap_or(false) {
        let _ = env.exception_clear();
    }
    result
}

fn string(env: &mut JNIEnv, object: JObject) -> Result<String> {
    if object.is_null() {
        return Ok(String::new());
    }
    Ok(env.get_string(&JString::from(object))?.into())
}

fn strings(env: &mut JNIEnv, object: JObject) -> Result<Vec<String>> {
    if object.is_null() {
        return Ok(Vec::new());
    }
    let array = JObjectArray::from(object);
    let len = env.get_array_length(&array)?;
    let mut values = Vec::new();
    for i in 0..len {
        let value = env.get_object_array_element(&array, i)?;
        values.push(string(env, value)?);
    }
    Ok(values)
}

fn pm<'a>(env: &mut JNIEnv<'a>, context: &JObject) -> Result<JObject<'a>> {
    Ok(env
        .call_method(
            context,
            "getPackageManager",
            "()Landroid/content/pm/PackageManager;",
            &[],
        )?
        .l()?)
}

pub fn files_dir() -> Result<std::path::PathBuf> {
    with_context(|env, context| {
        let file = env
            .call_method(context, "getFilesDir", "()Ljava/io/File;", &[])?
            .l()?;
        let path = env
            .call_method(&file, "getAbsolutePath", "()Ljava/lang/String;", &[])?
            .l()?;
        Ok(string(env, path)?.into())
    })
}

pub fn apps() -> Result<Vec<AppInfo>> {
    with_context(|env, context| {
        let uid = env
            .call_static_method("android/os/Process", "myUid", "()I", &[])?
            .i()?;
        if uid / 100000 != 0 {
            return Err(CoreError::new(
                "PRIMARY_USER_REQUIRED",
                "Install SysLeaf in the device owner profile (user 0).",
            ));
        }
        let manager = pm(env, context)?;
        let list = env
            .call_method(
                &manager,
                "getInstalledApplications",
                "(I)Ljava/util/List;",
                &[JValue::Int(8192)], // MATCH_UNINSTALLED_PACKAGES includes removed system apps.
            )?
            .l()?;
        let count = env.call_method(&list, "size", "()I", &[])?.i()?;
        let mut apps = Vec::new();
        for i in 0..count {
            let result: Result<AppInfo> = env.with_local_frame(128, |env| {
                let info = env
                    .call_method(&list, "get", "(I)Ljava/lang/Object;", &[JValue::Int(i)])?
                    .l()?;
                let package_object = env
                    .get_field(&info, "packageName", "Ljava/lang/String;")?
                    .l()?;
                let package = string(env, package_object)?;
                let label = env
                    .call_method(
                        &info,
                        "loadLabel",
                        "(Landroid/content/pm/PackageManager;)Ljava/lang/CharSequence;",
                        &[JValue::Object(&manager)],
                    )?
                    .l()?;
                let name_object = env
                    .call_method(&label, "toString", "()Ljava/lang/String;", &[])?
                    .l()?;
                let name = string(env, name_object)?;
                let source_obj = env
                    .get_field(&info, "sourceDir", "Ljava/lang/String;")?
                    .l()?;
                let source = string(env, source_obj)?;
                let splits_obj = env
                    .get_field(&info, "splitSourceDirs", "[Ljava/lang/String;")?
                    .l()?;
                let splits = strings(env, splits_obj)?;
                let lib_obj = env
                    .get_field(&info, "nativeLibraryDir", "Ljava/lang/String;")?
                    .l()?;
                let native_lib = string(env, lib_obj)?;
                let flags = env.get_field(&info, "flags", "I")?.i()?;
                let uid = env.get_field(&info, "uid", "I")?.i()?;
                let enabled = env.get_field(&info, "enabled", "Z")?.z()?;
                let category_int = env.get_field(&info, "category", "I")?.i()?;
                let (category, category_reason) = categories::classify(&package, category_int);
                if flags & 0x800000 == 0 {
                    // Removed apps are review-only entries, never mutation
                    // candidates. Their APK/permission metadata may be gone.
                    return Ok(AppInfo {
                        package,
                        name,
                        source,
                        splits,
                        native_lib,
                        system: flags & 1 != 0,
                        enabled,
                        installed: false,
                        category,
                        category_reason,
                        privileged_permissions: Vec::new(),
                        uid,
                        version: String::new(),
                        module_state: String::new(),
                        module_target: String::new(),
                        icon: None,
                    });
                }
                let package_string = env.new_string(&package)?;
                let package_info = env
                    .call_method(
                        &manager,
                        "getPackageInfo",
                        "(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;",
                        &[JValue::Object(&package_string), JValue::Int(4096 | 8192)],
                    )?
                    .l()?;
                let version_obj = env
                    .get_field(&package_info, "versionName", "Ljava/lang/String;")?
                    .l()?;
                let version = string(env, version_obj)?;
                let requested_obj = env
                    .get_field(&package_info, "requestedPermissions", "[Ljava/lang/String;")?
                    .l()?;
                let requested = strings(env, requested_obj)?;
                let mut privileged_permissions = Vec::new();
                for permission in requested {
                    let value = env.new_string(&permission)?;
                    let result = env.call_method(
                        &manager,
                        "getPermissionInfo",
                        "(Ljava/lang/String;I)Landroid/content/pm/PermissionInfo;",
                        &[JValue::Object(&value), JValue::Int(0)],
                    );
                    let pi = match result {
                        Ok(value) => value.l()?,
                        Err(jni::errors::Error::JavaException) => {
                            // A removed/nonexistent permission cannot be granted.
                            let exception = env.exception_occurred()?;
                            env.exception_clear()?;
                            if env.is_instance_of(
                                &exception,
                                "android/content/pm/PackageManager$NameNotFoundException",
                            )? {
                                continue;
                            }
                            return Err(CoreError::new(
                                "PERMISSION_QUERY_FAILED",
                                format!("Cannot inspect {permission}."),
                            ));
                        }
                        Err(error) => return Err(error.into()),
                    };
                    let protection = env.get_field(&pi, "protectionLevel", "I")?.i()?;
                    let owner_obj = env
                        .get_field(&pi, "packageName", "Ljava/lang/String;")?
                        .l()?;
                    let owner = string(env, owner_obj)?;
                    if (owner == "android" || owner == "com.android.car") && protection & 0x10 != 0
                    {
                        privileged_permissions.push(permission);
                    }
                }
                privileged_permissions.sort();
                privileged_permissions.dedup();
                Ok(AppInfo {
                    package,
                    name,
                    source,
                    splits,
                    native_lib,
                    system: flags & 1 != 0,
                    enabled,
                    installed: flags & 0x800000 != 0,
                    category,
                    category_reason,
                    privileged_permissions,
                    uid,
                    version,
                    module_state: String::new(),
                    module_target: String::new(),
                    icon: None,
                })
            });
            match result {
                Ok(app) => apps.push(app),
                Err(error) => {
                    if env.exception_check().unwrap_or(false) {
                        let _ = env.exception_clear();
                    }
                    // Never offer an app with incomplete permission metadata.
                    // A transient uninstall while enumerating can be retried.
                    return Err(CoreError::new("APP_QUERY_FAILED", error.to_string()));
                }
            }
        }
        Ok(apps)
    })
}

pub fn icon(package: &str) -> Result<String> {
    crate::modules::validate_package(package)?;
    with_context(|env, context| {
        env.with_local_frame(48, |env| {
            let manager = pm(env, context)?;
            let name = env.new_string(package)?;
            let drawable = env
                .call_method(
                    &manager,
                    "getApplicationIcon",
                    "(Ljava/lang/String;)Landroid/graphics/drawable/Drawable;",
                    &[JValue::Object(&name)],
                )?
                .l()?;
            let config = env
                .get_static_field(
                    "android/graphics/Bitmap$Config",
                    "ARGB_8888",
                    "Landroid/graphics/Bitmap$Config;",
                )?
                .l()?;
            let bitmap = env
                .call_static_method(
                    "android/graphics/Bitmap",
                    "createBitmap",
                    "(IILandroid/graphics/Bitmap$Config;)Landroid/graphics/Bitmap;",
                    &[JValue::Int(96), JValue::Int(96), JValue::Object(&config)],
                )?
                .l()?;
            let canvas = env.new_object(
                "android/graphics/Canvas",
                "(Landroid/graphics/Bitmap;)V",
                &[JValue::Object(&bitmap)],
            )?;
            env.call_method(
                &drawable,
                "setBounds",
                "(IIII)V",
                &[
                    JValue::Int(0),
                    JValue::Int(0),
                    JValue::Int(96),
                    JValue::Int(96),
                ],
            )?;
            env.call_method(
                &drawable,
                "draw",
                "(Landroid/graphics/Canvas;)V",
                &[JValue::Object(&canvas)],
            )?;
            let stream = env.new_object("java/io/ByteArrayOutputStream", "()V", &[])?;
            let format = env
                .get_static_field(
                    "android/graphics/Bitmap$CompressFormat",
                    "PNG",
                    "Landroid/graphics/Bitmap$CompressFormat;",
                )?
                .l()?;
            env.call_method(
                &bitmap,
                "compress",
                "(Landroid/graphics/Bitmap$CompressFormat;ILjava/io/OutputStream;)Z",
                &[
                    JValue::Object(&format),
                    JValue::Int(100),
                    JValue::Object(&stream),
                ],
            )?;
            let bytes = env.call_method(&stream, "toByteArray", "()[B", &[])?.l()?;
            let bytes = env.convert_byte_array(JByteArray::from(bytes))?;
            env.call_method(&bitmap, "recycle", "()V", &[])?;
            Ok(base64::engine::general_purpose::STANDARD.encode(bytes))
        })
    })
}

pub fn open_hybrid() -> Result<()> {
    with_context(|env, context| {
        let url = env.new_string(crate::model::HYBRID_URL)?;
        let uri = env
            .call_static_method(
                "android/net/Uri",
                "parse",
                "(Ljava/lang/String;)Landroid/net/Uri;",
                &[JValue::Object(&url)],
            )?
            .l()?;
        let action = env.new_string("android.intent.action.VIEW")?;
        let intent = env.new_object(
            "android/content/Intent",
            "(Ljava/lang/String;Landroid/net/Uri;)V",
            &[JValue::Object(&action), JValue::Object(&uri)],
        )?;
        env.call_method(
            &intent,
            "addFlags",
            "(I)Landroid/content/Intent;",
            &[JValue::Int(0x10000000)],
        )?;
        env.call_method(
            context,
            "startActivity",
            "(Landroid/content/Intent;)V",
            &[JValue::Object(&intent)],
        )?;
        Ok(())
    })
}
