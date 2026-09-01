# Movies & TV Experience Recommender

This project explores a way to recommend movies and TV shows based on the **experience a viewer is likely to have**, rather than relying on broad labels like genre, popularity, or ratings. The goal is to get closer to **what a title actually feels like to watch**.

The project uses audience review language to build profiles across 55 viewing-experience attributes, including *Comforting*, *Intense*, *Romantic*, *Haunting*, *Immersive*, *Unforgettable*, and *Reflective / thought-provoking*.

## Project overview

The pipeline:

1. Ingests 5.57 million IMDb audience reviews.
2. Converts the raw JSON files to Parquet for easier and more efficient processing.
3. Builds an inventory of frequently reviewed movie and TV titles.
4. Matches those titles to TMDB and adds structured metadata.
5. Cleans and validates the review data.
6. Uses sentence embeddings to compare review language with 55 experience definitions.
7. Aggregates the review-level similarities into title-level experience profiles.
8. Loads the final title metadata and experience scores into DuckDB.
9. Uses SQL to query titles by one or several viewing experiences.

## Key results

- **5,571,499** raw IMDb reviews ingested
- Raw data reduced from **7.09 GB of JSON to 3.94 GB of Parquet**
- **8,841** candidate titles selected for enrichment
- **7,726** high-confidence IMDb-to-TMDB matches
- **7,721** final movie and TV title profiles
- **2,723,221** cleaned reviews used for experience scoring
- **55** viewing-experience attributes
- **424,655** final title-experience records
- **0** duplicate title-experience records in the final dataset

During validation, I found that numeric TMDB IDs are not unique across movies and TV shows. There were **81 IDs** that appeared once as a movie and once as a TV show.

To handle that, I created a combined `title_key` using the media type and TMDB ID, for example:

```text
movie:155
tv:155
```

That key is used to join the final warehouse tables.

## Experience taxonomy

The 55 experience attributes are grouped into 10 categories:

- Emotion
- Overall experience
- Thinking / engagement
- Tone & style
- Story / world experience
- Connection
- Viewing style
- Atmosphere
- Themes / lens
- After-effect

Some examples are:

`Comforting`, `Bittersweet`, `Romantic`, `Intense`, `Immersive`, `Existential`, `Suspenseful / tense`, `Dark humor`, `Epic / grand`, `Strong chemistry`, `Slow-burn`, `Seasonal`, `Political`, `Unsettled`, and `Cathartic`.

The full taxonomy and definitions are in `05_experience_scoring.ipynb`.

## Semantic scoring

I tested two lightweight sentence-embedding models:

- `sentence-transformers/all-MiniLM-L6-v2`
- `BAAI/bge-small-en-v1.5`

MiniLM picked up some of the right emotional signals, but BGE gave more coherent matches in the test sample, so I used BGE for the full scoring run.

For each review:

1. The review text is converted into an embedding.
2. That embedding is compared with embeddings for all 55 experience definitions using cosine similarity.
3. The similarity values are added to running totals for the title.
4. The totals are divided by the number of reviews for that title to create average experience similarities.

All **2,723,221 cleaned reviews** contributed to scoring.

To make scoring the full dataset practical, each review was limited to a maximum model sequence length of 128 tokens.

I first benchmarked BGE locally, but the CPU speed was too slow for the full dataset. The full embedding run was therefore completed on a Tesla T4 GPU in Google Colab.

The scoring input was processed in 11 batches, with the title-level similarity totals from each batch saved as checkpoints and combined locally afterward.

## Experience scores

The raw cosine similarity is kept in the final dataset, but it is not a probability and is not very intuitive on its own.

To make the results easier to use, I also calculate a **0-100 percentile score for each experience**.

For example:

> A Comforting score of 90 means the title ranks higher than about 90% of the other titles in the dataset for Comforting.

It does not mean the title is literally "90% comforting."

This also makes it easier to combine several experience signals in recommendation queries.

## Analytical warehouse

The final analytical database is built with DuckDB and contains two main tables.

### `titles`

One row per movie or TV show, with fields including:

- `title_key`
- TMDB ID
- media type
- title
- original title
- overview
- genres
- original language
- release date
- runtime
- status
- popularity
- TMDB vote information
- production information
- TV season and episode counts when available

### `experience_scores`

One row for each title and experience combination:

- `title_key`
- TMDB ID
- media type
- experience
- category
- percentile score
- raw similarity
- reviews used

The two tables are joined using `title_key`.

## Example recommendation query

The warehouse can rank titles using more than one experience at a time.

For example, this query looks for titles that score highly across *Comforting*, *Warm / tender*, and *Romantic*:

```sql
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
```

Instead of asking for a romance genre, this is closer to asking:

> What can I watch that feels comforting, warm, and romantic?

More example and validation queries are in the `sql/` folder.

## Project structure

```text
movies-tv-data-project/
  data/
    sample/
      title_experience_sample.csv

  notebooks/
    00_imdb_source_profiling.ipynb
    01_imdb_ingestion.ipynb
    02_imdb_title_inventory.ipynb
    03_tmdb_enrichment.ipynb
    04_review_preprocessing.ipynb
    05_experience_scoring.ipynb
    06_warehouse_build.ipynb

  sql/
    example_queries.sql
    validation_queries.sql

  .gitignore
  README.md
  requirements.txt
```

The large raw, processed, checkpoint, and warehouse files are excluded from GitHub through `.gitignore`.

## Notebook workflow

| Notebook | What it does |
| --- | --- |
| `00_imdb_source_profiling.ipynb` | Profiles the raw IMDb review files and checks schema, volume, and missing values |
| `01_imdb_ingestion.ipynb` | Converts the raw JSON reviews to Parquet and validates the result |
| `02_imdb_title_inventory.ipynb` | Builds the title inventory and selects titles with enough review data |
| `03_tmdb_enrichment.ipynb` | Matches IMDb title strings to TMDB and retrieves metadata |
| `04_review_preprocessing.ipynb` | Filters, cleans, deduplicates, and prepares the reviews for scoring |
| `05_experience_scoring.ipynb` | Defines the taxonomy, compares embedding models, and creates the experience scores |
| `06_warehouse_build.ipynb` | Builds the DuckDB warehouse, validates the tables, and runs recommendation queries |

## Setup

Install the Python dependencies with:

```bash
pip install -r requirements.txt
```

The notebooks are organized in the order the pipeline was built, from `00` through `06`.

The full raw and processed datasets are not included in the repository because of their size.

A sample of the final title-experience output is included here:

```text
data/sample/title_experience_sample.csv
```

The GPU checkpoint files used during the full semantic scoring run are also not included.

## Limitations

There are a few important limitations to the current version:

- The experience scores come from audience review language, so they should not be treated as definitive labels for a title.
- Some of the 55 experiences overlap in meaning, which can lead to noisy matches.
- BGE Small is mainly an English-language model, so non-English reviews may not be represented as well.
- Review text was capped at a maximum model sequence length of 128 tokens during scoring.
- Percentile scores are relative to the titles included in this dataset.
- I did not have a human-labeled validation dataset for the 55 experience attributes.
- Titles with fewer reviews may have less stable profiles, which is why the example recommendation queries use a minimum review count.

## What I would add next

Some things I would explore in a future version:

- manually validating a sample of the experience scores
- improving support for multilingual reviews
- letting users give different weights to different experiences
- experimenting with review helpfulness as a weighting signal
- recommending similar titles based on their full 55-attribute profiles
- building a simple interactive recommendation interface
- moving parts of the pipeline and warehouse to cloud infrastructure