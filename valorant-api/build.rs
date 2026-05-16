// "https://api.swaggerhub.com/apis/Henrik-3/HenrikDev-API/4.2.1"

use openapiv3::OpenAPI;
use serde::de::Deserialize;
use serde_json::Value;

const SPEC_PATH: &str = "spec.json";
const SWAGGER_URL: &str = "https://app.swaggerhub.com/apiproxy/registry/Henrik-3/HenrikDev-API";

async fn get_spec() -> anyhow::Result<Value> {
    println!("Fetching version from {}", SWAGGER_URL);
    let client = wreq::Client::new();
    let resp = client
        .get(SWAGGER_URL)
        .send()
        .await?
        .error_for_status()?
        .json::<Value>()
        .await?;
    let version = resp.get("defaultVersion").map(|v| v.as_str()).flatten();
    if let Some(version) = version {
        println!("Found version: {}", version);
        let spec_url = format!(
            "https://api.swaggerhub.com/apis/Henrik-3/HenrikDev-API/{}",
            version
        );
        println!("Fetching latest spec from {}", spec_url);
        let spec: Value = client.get(&spec_url).send().await?.json().await?;
        Ok(spec)
    } else {
        Err(anyhow::anyhow!("No default version found"))
    }
}

fn patch_operation_ids(spec: &mut Value) {
    let Some(paths) = spec.get_mut("paths").and_then(|p| p.as_object_mut()) else {
        return;
    };

    let methods = [
        "get", "put", "post", "delete", "options", "head", "patch", "trace",
    ];

    for (path, path_item) in paths {
        let Some(path_item) = path_item.as_object_mut() else {
            continue;
        };

        for method in methods {
            let Some(op) = path_item.get_mut(method).and_then(|o| o.as_object_mut()) else {
                continue;
            };

            if !op.contains_key("operationId") {
                let operation_id = derive_operation_id(method, path);
                op.insert("operationId".to_string(), Value::String(operation_id));
            }
        }
    }
}

fn derive_operation_id(method: &str, path: &str) -> String {
    // "/valorant/v1/account/{name}/{tag}" + "get"
    // -> "get_valorant_v1_account_name_tag"
    let segments = path
        .split('/')
        .filter(|s| !s.is_empty())
        .map(|s| {
            // strip curly braces from path params: {name} -> name
            s.trim_start_matches('{').trim_end_matches('}')
        })
        .collect::<Vec<_>>()
        .join("_");

    format!("{}_{}", method, segments)
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    println!("cargo:rerun-if-changed={}", SPEC_PATH);

    // Fetch and cache the spec if it doesn't exist yet
    if !std::path::Path::new(SPEC_PATH).exists() {
        let mut spec = get_spec().await.unwrap();
        patch_operation_ids(&mut spec);
        let file = std::fs::File::create(SPEC_PATH).unwrap();
        serde_json::to_writer_pretty(file, &spec).unwrap();
    }

    let file = std::fs::File::open(SPEC_PATH).unwrap();
    let spec: OpenAPI = serde_json::from_reader(file).unwrap();

    let mut generator = progenitor::Generator::default();
    let tokens = generator.generate_tokens(&spec).unwrap();
    let ast = syn::parse2(tokens).unwrap();
    let content = prettyplease::unparse(&ast);

    let mut out_file = std::path::Path::new(&std::env::var("OUT_DIR").unwrap()).to_path_buf();
    out_file.push("codegen.rs");

    std::fs::write(out_file, content).unwrap();
}
