-- Create guild preferences table
CREATE TABLE IF NOT EXISTS guild_preferences (
    id INTEGER PRIMARY KEY,
    guild_id INTEGER,
    preferences TEXT NOT NULL,
    UNIQUE (guild_id)
);

-- Table that holds the downloaded premier schedule
CREATE TABLE IF NOT EXISTS premier_schedule (
    id INTEGER PRIMARY KEY,
    region TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    data TEXT NOT NULL
);
