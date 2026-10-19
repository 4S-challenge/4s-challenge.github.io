-- 혼자 하기 한 판. 비밀 숫자는 서버에만 있고, 판정도 서버에서 한다.
CREATE TABLE IF NOT EXISTS solo_games (
  id          TEXT PRIMARY KEY,
  secret      TEXT    NOT NULL,
  started_at  INTEGER NOT NULL,           -- epoch ms
  tries       INTEGER NOT NULL DEFAULT 0,
  solved_at   INTEGER,                    -- 4S 나온 시각, epoch ms
  ranked      INTEGER NOT NULL DEFAULT 0  -- 랭킹 등록 여부 (한 판에 한 번)
);

CREATE INDEX IF NOT EXISTS idx_solo_games_started ON solo_games (started_at);

-- 랭킹. 적은 시도 → 짧은 시간 → 먼저 등록 순.
CREATE TABLE IF NOT EXISTS rankings (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  game_id      TEXT    NOT NULL UNIQUE,
  initials     TEXT    NOT NULL,
  tries        INTEGER NOT NULL,
  duration_ms  INTEGER NOT NULL,
  created_at   INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rankings_order ON rankings (tries, duration_ms, created_at);
