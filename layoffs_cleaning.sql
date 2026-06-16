-- DATA CLEANING PROJECT

-- Creates a staging copy of the original dataset
CREATE TABLE layoffs_staging LIKE layoffs;

SELECT * FROM layoffs_staging;

INSERT INTO layoffs_staging
SELECT * FROM layoffs;


-- 1. Remove Duplicates

-- Step 1: Identifies duplicate records using ROW_NUMBER()
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, 
`date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- Step 2: Creates a clean table to store deduplicated data
CREATE TABLE `layoffs_clean` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT -- Created column
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Step 3: Inserts data and assigns row numbers to duplicate groups
INSERT INTO layoffs_clean
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, 
`date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

-- Step 4: Displays duplicates
SELECT *
FROM layoffs_clean
WHERE row_num > 1;

-- Step 5: Removes duplicates, keeping the first occurrence
DELETE
FROM layoffs_clean
WHERE row_num > 1;

-- Result: Displays the final cleaned dataset
SELECT *
FROM layoffs_clean;


-- 2. Standardize the Data

-- Step 1: Removes leading and trailing spaces from company names
SELECT DISTINCT company 
FROM layoffs_clean;

UPDATE layoffs_clean
SET company = TRIM(company);

-- Step 2: Standardizes industry names by grouping Crypto variations
SELECT DISTINCT industry
FROM layoffs_clean ORDER BY 1;

SELECT * FROM layoffs_clean
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_clean
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Step 3: Removes unnecessary punctuation from country names
SELECT DISTINCT country
FROM layoffs_clean ORDER BY 1;

SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_clean ORDER BY 1;

UPDATE layoffs_clean
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Step 4: Converts date values from text and changes the column type to DATE
SELECT `date` FROM layoffs_clean;

SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_clean;

UPDATE layoffs_clean
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_clean
MODIFY COLUMN `date` DATE;


-- 3. Populate Null or blank values

-- Step 1: Identifies blank or null industry values
SELECT DISTINCT industry
FROM layoffs_clean
WHERE industry IS NULL OR industry = '';

-- Step 2: Converts blank industry values to NULL
UPDATE layoffs_clean
SET industry = NULL
WHERE industry = '';

-- Step 3: Uses a self join to populate missing industry values
SELECT t1.industry, t2.industry
FROM layoffs_clean t1
JOIN layoffs_clean t2
	ON t1.company = t2.company
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;
 
UPDATE layoffs_clean t1
JOIN layoffs_clean t2
	ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

SELECT *
FROM layoffs_clean
WHERE industry IS NULL;

-- One company still has missing industry information.
-- Since no matching records are available, the value cannot be populated.
-- In a real-world scenario, additional research could be performed.
-- to retrieve the missing information. 


-- 4. Remove Unnecessary Data

-- Step 1: Removes records where both layoff metrics are missing
SELECT *
FROM layoffs_clean
WHERE total_laid_off  IS NULL
AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_clean
WHERE total_laid_off  IS NULL
AND percentage_laid_off IS NULL;

-- Step 2: Removes the helper column used to identify duplicates
ALTER TABLE layoffs_clean
DROP COLUMN row_num;

SELECT *
FROM layoffs_clean;

-- Data cleaning completed 

SELECT COUNT(*)
FROM layoffs_staging;

SELECT COUNT(*)
FROM layoffs_clean;