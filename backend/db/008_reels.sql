CREATE TABLE IF NOT EXISTS reels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  object_key TEXT NOT NULL UNIQUE,
  caption VARCHAR(2000) NOT NULL DEFAULT '',
  category VARCHAR(32) NOT NULL,
  content_type VARCHAR(100) NOT NULL CHECK (content_type = 'video/mp4'),
  size_bytes BIGINT NOT NULL CHECK (size_bytes BETWEEN 1 AND 157286400),
  duration_seconds INTEGER CHECK (duration_seconds BETWEEN 1 AND 180),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT reels_category_allowed CHECK (
    category IN (
      'sports',
      'gaming',
      'entertainment',
      'religion',
      'education',
      'design',
      'technology',
      'news',
      'fashion',
      'cooking',
      'travel',
      'science',
      'comedy',
      'art',
      'global_trends'
    )
  )
);

CREATE INDEX IF NOT EXISTS reels_feed_idx
  ON reels (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS reels_author_idx
  ON reels (author_id, created_at DESC);
