-- Join title metadata to the experience scores used in the analysis.
-- Each row represents one title and one viewing experience.

CREATE OR REPLACE VIEW analysis_dataset AS

SELECT
    t.title_key,
    t.tmdb_id,
    t.media_type,
    t.title,
    t.release_date,
    EXTRACT(YEAR FROM t.release_date) AS release_year,
    t.original_language,
    t.runtime,
    t.popularity,
    t.vote_average,
    t.vote_count,
    t.number_of_seasons,
    t.number_of_episodes,
    e.experience,
    e.category,
    e.score,
    e.reviews_used

FROM titles AS t

INNER JOIN experience_scores AS e
    ON t.title_key = e.title_key
    AND t.media_type = e.media_type;
