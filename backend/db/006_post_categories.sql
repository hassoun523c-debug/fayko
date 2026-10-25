ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS category VARCHAR(32) NOT NULL DEFAULT 'general';

ALTER TABLE posts
  DROP CONSTRAINT IF EXISTS posts_category_allowed;

ALTER TABLE posts
  ADD CONSTRAINT posts_category_allowed CHECK (
    category IN (
      'general',
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
  );

CREATE INDEX IF NOT EXISTS posts_category_feed_idx
  ON posts (category, created_at DESC, id DESC);
