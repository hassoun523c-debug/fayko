ALTER TABLE users
  ADD COLUMN IF NOT EXISTS interests TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_interests_allowed;

ALTER TABLE users
  ADD CONSTRAINT users_interests_allowed CHECK (
    interests <@ ARRAY[
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
    ]::TEXT[]
    AND cardinality(interests) <= 15
  );
