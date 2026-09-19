-- Profile the audience rating and vote-count distributions.
-- The low-vote checks help set a minimum threshold for later analysis.

SELECT
    media_type,
    COUNT(*) AS title_count,

    ROUND(AVG(vote_average), 2) AS avg_rating,
    ROUND(MEDIAN(vote_average), 2) AS median_rating,
    MIN(vote_average) AS min_rating,
    MAX(vote_average) AS max_rating,

    ROUND(AVG(vote_count), 0) AS avg_vote_count,
    ROUND(MEDIAN(vote_count), 0) AS median_vote_count,
    QUANTILE_CONT(vote_count, 0.25) AS vote_count_25th,
    QUANTILE_CONT(vote_count, 0.75) AS vote_count_75th,

    SUM(CASE WHEN vote_average = 0 THEN 1 ELSE 0 END) AS zero_ratings,
    SUM(CASE WHEN vote_count = 0 THEN 1 ELSE 0 END) AS zero_votes,
    SUM(CASE WHEN vote_count < 10 THEN 1 ELSE 0 END) AS under_10_votes

FROM titles

WHERE
    vote_average IS NOT NULL
    AND vote_count IS NOT NULL

GROUP BY media_type

ORDER BY media_type;
