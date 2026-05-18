// Technically I found a more updated spec here: https://api.henrikdev.xyz/openapi.json
// Problems:
//  1. It's OpenAPI 3.1, which causes problems for progenitor. I did find oas3 and oas3-gen that could handle this
//  2. It doesn't have the premier schedule at v1/valorant/premier/seasons/{region}

use openapiv3::OpenAPI;
use serde::Deserialize;
use serde_json::Value;
use wreq::Client;

const SPEC_PATH: &str = "spec.json";
const SWAGGER_URL: &str = "https://app.swaggerhub.com/apiproxy/registry/Henrik-3/HenrikDev-API";

async fn get_latest_version(client: &Client) -> anyhow::Result<String> {
    let resp = client
        .get(SWAGGER_URL)
        .send()
        .await?
        .error_for_status()?
        .json::<Value>()
        .await?;
    let version = resp.get("defaultVersion").map(|v| v.as_str()).flatten();
    if let Some(version) = version {
        Ok(version.to_string())
    } else {
        Err(anyhow::anyhow!("No default version found"))
    }
}

async fn get_spec(client: &Client, version: &str) -> anyhow::Result<Value> {
    let spec_url = format!(
        "https://api.swaggerhub.com/apis/Henrik-3/HenrikDev-API/{}",
        version
    );
    let spec: Value = client.get(&spec_url).send().await?.json().await?;
    Ok(spec)
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

async fn patch_valorant_maps(client: &Client, spec: &mut Value) {
    #[derive(Deserialize, Debug)]
    struct Map {
        #[serde(rename = "displayName")]
        display_name: String,
        #[serde(rename = "tacticalDescription")]
        tactical_description: Option<String>,
    }
    // While this is an outdated api version, we're stuck with it and its maps are incorrect
    // Fetch latest maps from valorant api
    let url = "https://valorant-api.com/v1/maps";
    let resp = client.get(url).send().await.unwrap();
    let data = resp.json::<Value>().await.unwrap();
    let data = data.get("data").unwrap();

    // Only competitive maps have tactical descriptions
    let maps: Vec<Map> = serde_json::from_value(data.clone()).unwrap();
    let map_names = maps
        .iter()
        .filter(|m| m.tactical_description.is_some())
        .map(|m| m.display_name.clone())
        .collect::<Vec<_>>();

    // Patch the spec at components.schemas.maps.enum
    if let Some(schemas) = spec
        .get_mut("components")
        .and_then(|c| c.get_mut("schemas"))
    {
        if let Some(maps) = schemas.get_mut("maps") {
            if let Some(enum_values) = maps.get_mut("enum") {
                *enum_values = map_names.into();
            }
        }
    }
}

fn patch_premier_event_types(spec: &mut Value) {
    // spec is missing scrim type at compoments.schemas.premier_seasons_event_types
    if let Some(schemas) = spec
        .get_mut("components")
        .and_then(|c| c.get_mut("schemas"))
    {
        if let Some(event_types) = schemas.get_mut("premier_seasons_event_types") {
            if let Some(enum_values) = event_types.get_mut("enum") {
                enum_values.as_array_mut().unwrap().push("SCRIM".into())
            }
        }
    }
}

fn patch_premier_conferences(spec: &mut Value) {
    // components.schemas.premier_conferences is missing the following conferences
    // as found through cargo test -p neonbot test_get_current_season

    let extra: Vec<Value> = vec![
        "NA_SUPER".into(),
        // can we talk about how europe is such a headache? i mean look at all these entries 😕
        "EU_TURKEY_SUPER".into(),
        "EU_MIDDLE_EAST_SUPER".into(),
        "EU_DACH".into(),
        "EU_IBIT".into(),
        "EU_FRANCE".into(),
        "EU_EAST".into(),
        "EU_DACH_SUPER".into(),
        "EU_IBIT_SUPER".into(),
        "EU_FRANCE_SUPER".into(),
        "EU_EAST_SUPER".into(),
        "EU_NORTH".into(),
        "EU_NORTH_SUPER".into(),
        "KR_KOREA_SUPER".into(),
        "AP_OCEANIA_SUPER".into(),
        "AP_ASIA_SUPER".into(),
        "AP_JAPAN_SUPER".into(),
        "AP_SOUTH_ASIA_SUPER".into(),
        "BR_BRAZIL_SUPER".into(),
        "LATAM_NORTH_SUPER".into(),
        "LATAM_SOUTH_SUPER".into(),
    ];

    if let Some(schemas) = spec
        .get_mut("components")
        .and_then(|c| c.get_mut("schemas"))
    {
        if let Some(conferences) = schemas.get_mut("premier_conferences") {
            if let Some(enum_values) = conferences.get_mut("enum") {
                enum_values
                    .as_array_mut()
                    .unwrap()
                    .extend(extra.into_iter());
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
    let client = wreq::Client::new();

    // Get the latest version and cache it into a file so cargo rebuilds if we
    // find a new version
    let version = get_latest_version(&client).await.unwrap();
    if std::fs::read_to_string(".version").is_ok_and(|v| v == version) {
        return;
    }
    std::fs::write(".version", &version).unwrap();
    println!("cargo:rerun-if-changed=.version");

    // Fetch the spec from the api and patch it
    let mut spec = get_spec(&client, &version).await.unwrap();
    patch_operation_ids(&mut spec);
    patch_premier_event_types(&mut spec);
    patch_premier_conferences(&mut spec);
    patch_valorant_maps(&client, &mut spec).await;

    // Save the patched version to disk and tell cargo to only rebuild this package if
    // this file changes
    let file = std::fs::File::create(SPEC_PATH).unwrap();
    serde_json::to_writer_pretty(file, &spec).unwrap();
    println!("cargo:rerun-if-changed={}", SPEC_PATH);

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
