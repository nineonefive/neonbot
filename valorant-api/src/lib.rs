use reqwest::header::HeaderMap;

include!(concat!(env!("OUT_DIR"), "/codegen.rs"));

impl Client {
    pub fn new_with_token(token: &str) -> Self {
        let mut headers = HeaderMap::new();
        headers.insert(
            "Authorization",
            reqwest::header::HeaderValue::from_str(token).unwrap(),
        );
        let client = reqwest::ClientBuilder::new()
            .default_headers(headers)
            .build()
            .unwrap();
        Self::new_with_client("https://api.henrikdev.xyz", client)
    }
}
