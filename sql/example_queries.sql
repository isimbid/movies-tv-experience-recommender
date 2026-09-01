-- Find titles that rank highest for one experience
SELECT
    t.title,
    t.media_type,
    t.release_date,
    e.score,
    e.raw_similarity,
    e.reviews_used
FROM experience_scores e
JOIN titles t
    ON e.title_key = t.title_key
WHERE
    e.experience = 'Comforting'
    AND e.reviews_used >= 100
ORDER BY e.score DESC
LIMIT 20;


-- Combine several experience signals into one recommendation
SELECT
    t.title,
    t.media_type,
    t.release_date,
    ROUND(AVG(e.score), 2) AS experience_match_score,
    MIN(e.reviews_used) AS reviews_used
FROM experience_scores e
JOIN titles t
    ON e.title_key = t.title_key
WHERE
    e.experience IN (
        'Comforting',
        'Warm / tender',
        'Romantic'
    )
    AND e.reviews_used >= 100
GROUP BY
    t.title_key,
    t.title,
    t.media_type,
    t.release_date
HAVING COUNT(DISTINCT e.experience) = 3
ORDER BY experience_match_score DESC
LIMIT 20;


-- Show the strongest experience signals for one title
SELECT
    t.title,
    e.experience,
    e.category,
    e.score,
    e.raw_similarity,
    e.reviews_used
FROM experience_scores e
JOIN titles t
    ON e.title_key = t.title_key
WHERE e.title_key = 'movie:155'
ORDER BY e.score DESC
LIMIT 10;