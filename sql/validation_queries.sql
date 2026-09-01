-- Check the title table
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT title_key) AS unique_title_keys,
    COUNT(*) - COUNT(DISTINCT title_key) AS duplicate_title_keys,
    SUM(CASE WHEN title_key IS NULL THEN 1 ELSE 0 END) AS missing_title_keys
FROM titles;


-- Check the experience score table
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT title_key) AS titles,
    COUNT(DISTINCT experience) AS experiences,
    COUNT(*) - COUNT(DISTINCT (title_key, experience)) AS duplicate_pairs,
    SUM(CASE WHEN score IS NULL THEN 1 ELSE 0 END) AS missing_scores
FROM experience_scores;


-- Check for experience scores without a matching title
SELECT
    COUNT(*) AS orphan_score_rows
FROM experience_scores e
LEFT JOIN titles t
    ON e.title_key = t.title_key
WHERE t.title_key IS NULL;


-- Check that identifiers agree across both tables
SELECT
    COUNT(*) AS identifier_mismatches
FROM experience_scores e
JOIN titles t
    ON e.title_key = t.title_key
WHERE
    e.tmdb_id <> t.tmdb_id
    OR e.media_type <> t.media_type;


-- Check that every title has all 55 experience scores
SELECT
    MIN(experience_count) AS min_experiences,
    MAX(experience_count) AS max_experiences
FROM (
    SELECT
        title_key,
        COUNT(*) AS experience_count
    FROM experience_scores
    GROUP BY title_key
);


-- Count the reviews represented without counting each title 55 times
SELECT
    SUM(reviews_used) AS reviews_represented
FROM (
    SELECT DISTINCT
        title_key,
        reviews_used
    FROM experience_scores
);