use actix_web::{get, web, App, HttpResponse, HttpServer, Responder};
use actix_cors::Cors;
use serde::{Deserialize, Serialize};
use std::env;

#[derive(Serialize, Deserialize)]
struct ApiInfo {
    name: String,
    version: String,
    language: String,
    framework: String,
    description: String,
}

#[derive(Serialize, Deserialize)]
struct HealthResponse {
    status: String,
    timestamp: String,
}

#[get("/")]
async fn root() -> impl Responder {
    let info = ApiInfo {
        name: "DevStack Core Rust Reference API".to_string(),
        version: "1.0.0".to_string(),
        language: "Rust".to_string(),
        framework: "Actix-web".to_string(),
        description: "Rust reference implementation for infrastructure integration".to_string(),
    };
    HttpResponse::Ok().json(info)
}

#[get("/health/")]
async fn health() -> impl Responder {
    let response = HealthResponse {
        status: "healthy".to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
    };
    HttpResponse::Ok().json(response)
}

#[get("/health/vault")]
async fn health_vault() -> impl Responder {
    let vault_addr = env::var("VAULT_ADDR").unwrap_or_else(|_| "http://vault:8200".to_string());

    match reqwest::get(format!("{}/v1/sys/health", vault_addr)).await {
        Ok(resp) if resp.status().is_success() => {
            HttpResponse::Ok().json(serde_json::json!({
                "status": "healthy"
            }))
        }
        _ => HttpResponse::ServiceUnavailable().json(serde_json::json!({
            "status": "unhealthy",
            "error": "Vault unavailable"
        }))
    }
}

#[get("/metrics")]
async fn metrics() -> impl Responder {
    HttpResponse::Ok()
        .content_type("text/plain")
        .body("# Rust API metrics placeholder\n")
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));

    let port = env::var("HTTP_PORT")
        .unwrap_or_else(|_| "8004".to_string())
        .parse::<u16>()
        .unwrap_or(8004);

    log::info!("Starting Rust API on port {}", port);

    HttpServer::new(|| {
        let cors = Cors::permissive();

        App::new()
            .wrap(cors)
            .service(root)
            .service(health)
            .service(health_vault)
            .service(metrics)
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::{test, App};

    #[actix_web::test]
    async fn test_root_endpoint() {
        let app = test::init_service(App::new().service(root)).await;
        let req = test::TestRequest::get().uri("/").to_request();
        let resp = test::call_service(&app, req).await;

        assert!(resp.status().is_success());

        let body: ApiInfo = test::read_body_json(resp).await;
        assert_eq!(body.name, "DevStack Core Rust Reference API");
        assert_eq!(body.version, "1.0.0");
        assert_eq!(body.language, "Rust");
        assert_eq!(body.framework, "Actix-web");
    }

    #[actix_web::test]
    async fn test_health_endpoint() {
        let app = test::init_service(App::new().service(health)).await;
        let req = test::TestRequest::get().uri("/health/").to_request();
        let resp = test::call_service(&app, req).await;

        assert!(resp.status().is_success());

        let body: HealthResponse = test::read_body_json(resp).await;
        assert_eq!(body.status, "healthy");
        assert!(!body.timestamp.is_empty());
    }

    #[actix_web::test]
    async fn test_metrics_endpoint() {
        let app = test::init_service(App::new().service(metrics)).await;
        let req = test::TestRequest::get().uri("/metrics").to_request();
        let resp = test::call_service(&app, req).await;

        assert!(resp.status().is_success());

        let body = test::read_body(resp).await;
        let body_str = std::str::from_utf8(&body).unwrap();
        assert!(body_str.contains("Rust API metrics placeholder"));
    }

    #[test]
    fn test_api_info_serialization() {
        let info = ApiInfo {
            name: "Test API".to_string(),
            version: "1.0.0".to_string(),
            language: "Rust".to_string(),
            framework: "Actix-web".to_string(),
            description: "Test description".to_string(),
        };

        let json = serde_json::to_string(&info).unwrap();
        assert!(json.contains("Test API"));
        assert!(json.contains("1.0.0"));
        assert!(json.contains("Rust"));
    }

    #[test]
    fn test_health_response_serialization() {
        let response = HealthResponse {
            status: "healthy".to_string(),
            timestamp: "2025-01-01T00:00:00Z".to_string(),
        };

        let json = serde_json::to_string(&response).unwrap();
        assert!(json.contains("healthy"));
        assert!(json.contains("2025-01-01T00:00:00Z"));
    }
}
