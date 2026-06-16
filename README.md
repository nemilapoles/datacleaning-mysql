# Data Cleaning in MySQL

## Contexto
O dataset contém informações sobre layoffs (demissões em massa) ocorridas em empresas de diversos países, contendo informações como empresa, setor, localização, data, estágio da empresa e número de funcionários desligados.

## Objetivo
O objetivo desse projeto foi aplicar técnicas de limpeza e padronização de dados utilizando o SQL para preparar o dataset para análises futuras.

Começamos importando os dados:

1. Criar novo schema;
2. “Table Data Import Wizard”;
3. Selecionar base de dados ‘layoffs’.

# Removendo Duplicatas

1. Criamos uma cópia da estrutura da tabela e inserimos os dados nela, sendo isso mais seguro na manipulação e limpeza de dados (evita estragar dados originais, permite testar transformações, segue as boas práticas):

```sql
CREATE TABLE layoffs_staging
LIKE layoffs;

SELECT *
FROM layoffs_staging;

INSERT INTO layoffs_staging
SELECT *
FROM layoffs;
```

2. Criamos uma CTE e adicionamos uma nova coluna enumerada com o `ROW_NUMBER( )`, permitindo identificar quais registros representam a primeira ocorrência e quais são duplicatas:

```sql
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
```

`ROW_NUMBER( )` - Enumera as linhas de cada grupo;
`PARTITION BY` - Define as colunas que serão levadas em conta na comparação dos dados iguais, como se dissesse “Agrupe todas as linhas que possuem exatamente os mesmos valores nessas colunas.”

3. Também é adicionada uma coluna enumerada para identificar os registros duplicados:

```sql
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
  `row_num` INT -- criação de coluna
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_clean
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, 
`date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;
```

4. Por final, as duplicatas são identificadas, removidas e o conjunto de dados limpo é obtido.

```sql
SELECT *
FROM layoffs_clean
WHERE row_num > 1;

DELETE
FROM layoffs_clean
WHERE row_num > 1;

SELECT *
FROM layoffs_clean;
```

---

# Padronização dos dados

1. Removemos espaços em branco no começo e no final do nome da coluna “*company*” usando `TRIM( )`:

```sql
SELECT DISTINCT company 
FROM layoffs_clean;

UPDATE layoffs_clean
SET company = TRIM(company);
```

2. Padronizamos o nome das categorias da coluna “*industry*” que se encontravam repetidas em 3 variações:

```sql
SELECT DISTINCT industry
FROM layoffs_clean ORDER BY 1;

SELECT * FROM layoffs_clean
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_clean
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';
```

3. Removemos pontuação desnecessária da coluna “*country*”:

```sql
SELECT DISTINCT country
FROM layoffs_clean ORDER BY 1;

SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_clean ORDER BY 1;

UPDATE layoffs_clean
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';
```

4. A coluna estava armazenada como *string.* Utilizamos a função `STR_TO_DATE()` para converter os valores para o formato de data reconhecido pelo MySQL e, posteriormente, alteramos o tipo da coluna para `DATE`: 

```sql
SELECT `date` FROM layoffs_clean;

SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_clean;

UPDATE layoffs_clean
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_clean
MODIFY COLUMN `date` DATE;
```

---

# Preenchimento de valores nulos

1. Identificamos valores em branco na coluna “*industry”* os os transformamos em valores nulos:

```sql
SELECT DISTINCT industry
FROM layoffs_clean
WHERE industry IS NULL OR industry = '';

UPDATE layoffs_clean
SET industry = NULL
WHERE industry = '';
```

2. Como uma mesma empresa pode aparecer diversas vezes na base, utilizamos um *self join* para localizar registros da mesma empresa que possuíam o campo “*industry”* preenchido e utilizá-los para completar os registros onde essa informação estava ausente:

```sql
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
WHERE industry IS NULL
```

<aside>
❕

Uma empresa ainda possui o campo de setor não preenchido. Como não há registros correspondentes disponíveis, esse valor não pode ser recuperado automaticamente. Em um cenário real, seria possível realizar uma pesquisa adicional para encontrar a informação faltante.

</aside>

---

# Remover dados desnecessários

1. Removemos entradas onde as duas métricas de demissões estão vazias:

```sql
SELECT *
FROM layoffs_clean
WHERE total_laid_off  IS NULL
AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_clean
WHERE total_laid_off  IS NULL
AND percentage_laid_off IS NULL;
```

2. Como a coluna `row_num` foi criada apenas para auxiliar na identificação das duplicatas, ela não possui utilidade para análises futuras e pode ser removida da tabela final:

```sql
ALTER TABLE layoffs_clean
DROP COLUMN row_num;

SELECT *
FROM layoffs_clean;
```

---

## Resultados obtidos:

- Remoção de duplicatas;
- Padronização de categorias;
- Conversão das datas;
- Tratamento de valores nulos;
- Remoção de registros sem informações relevantes;
- Dataset preparado para análises.

---

## Contagem de registros:

```sql
SELECT COUNT(*)
FROM layoffs_staging;

SELECT COUNT(*)
FROM layoffs_clean;
```

Registros antes da limpeza:
**2361**

Registros depois da limpeza:
**1995 (84,5%)**

Registros removidos:
**366 (15,5%)**
