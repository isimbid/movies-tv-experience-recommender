-- Build a recommendation pool for each viewing experience.
-- Candidates need a very strong experience match and solid audience reception.

WITH media_baselines AS (

    SELECT
        media_type,
        AVG(vote_average) AS media_avg_rating,
        MEDIAN(vote_count) AS media_median_votes,
        QUANTILE_CONT(vote_count, 0.25) AS vote_count_25th

    FROM titles

    WHERE
        vote_count >= 10
        AND vote_average > 0

    GROUP BY media_type
),

adjusted_titles AS (

    SELECT
        t.title_key,
        t.media_type,
        t.title,
        t.release_date,
        t.vote_average,
        t.vote_count,
        t.popularity,
        b.vote_count_25th,

        (
            (t.vote_count / (t.vote_count + b.media_median_votes))
            * t.vote_average
        )
        +
        (
            (b.media_median_votes / (t.vote_count + b.media_median_votes))
            * b.media_avg_rating
        ) AS adjusted_rating

    FROM titles AS t

    INNER JOIN media_baselines AS b
        ON t.media_type = b.media_type

    WHERE
        t.vote_count >= 10
        AND t.vote_average > 0
),

ranked_titles AS (

    SELECT
        *,
        PERCENT_RANK() OVER (
            PARTITION BY media_type
            ORDER BY adjusted_rating
        ) AS reception_percentile

    FROM adjusted_titles
)

SELECT
    r.media_type,
    r.title,
    r.release_date,
    e.experience,
    e.category,
    ROUND(e.score, 1) AS experience_score,
    r.vote_average,
    r.vote_count,
    ROUND(r.adjusted_rating, 2) AS adjusted_rating,
    ROUND(r.reception_percentile * 100, 1) AS reception_percentile

FROM ranked_titles AS r

INNER JOIN experience_scores AS e
    ON r.title_key = e.title_key
    AND r.media_type = e.media_type

WHERE
    -- Top 10% experience match.
    e.score >= 90

    -- Keep solid titles outside the top 20% seed group.
    AND r.reception_percentile >= 0.60
    AND r.reception_percentile < 0.80

    -- Require at least the 25th-percentile vote count for the format.
    AND r.vote_count >= r.vote_count_25th

ORDER BY
    r.media_type,
    e.experience,
    e.score DESC,
    r.adjusted_rating DESC;
