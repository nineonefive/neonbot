use sqlx::SqlitePool;
use sqlx::sqlite::SqliteConnectOptions;

pub async fn get_db() -> anyhow::Result<SqlitePool> {
    let options = SqliteConnectOptions::new()
        .filename("neonbot.db")
        .create_if_missing(true);
    let pool = SqlitePool::connect_with(options).await?;
    sqlx::migrate!().run(&pool).await?;
    Ok(pool)
}
