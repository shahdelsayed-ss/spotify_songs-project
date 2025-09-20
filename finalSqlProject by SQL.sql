--============== exploring data ==========================
---understanding  data
select * 
from
    [dbo].[spotify_songs_dataset]

--show nulls
select *
from
    [dbo].[spotify_songs_dataset]
where
    [song_id] is null
    or [song_title] is null
    or [artist] is null
    or [album] is null
    or [genre] is null
    or [release_date] is null
    or [duration] is null
    or [popularity] is null
    or [stream] is null
    or [language] is null
    or [explicit_content] is null
    or [label] is null
    or [collaboration] is null


select 
    [duration]
from
    [dbo].[spotify_songs_dataset]
where 
    [duration] is null

select 
    [language]
from
    [dbo].[spotify_songs_dataset]
where 
    [language] is null

select 
    [collaboration]
from
    [dbo].[spotify_songs_dataset]
where 
    [collaboration] is null

---show outliers
WITH stats AS (
    SELECT  
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY [duration]) OVER() AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY [duration]) OVER() AS Q3
    FROM [dbo].[spotify_songs_dataset]
)
SELECT t.[duration]
FROM [dbo].[spotify_songs_dataset] t
CROSS JOIN (SELECT TOP 1 Q1, Q3 FROM stats) s
WHERE t.[duration] < (s.Q1 - 1.5 * (s.Q3 - s.Q1))
   OR t.[duration] > (s.Q3 + 1.5 * (s.Q3 - s.Q1));


/*=========  Conclusions  ========
    there is a nulls in 
        [duration]       =
        [language]       =
        [collaboration]  =


*/

--================data cleaning
-------removing outliers
WITH stats AS (
    SELECT  
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY [duration]) OVER() AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY [duration]) OVER() AS Q3
    FROM [dbo].[spotify_songs_dataset]
)
DELETE t
FROM [dbo].[spotify_songs_dataset] t
CROSS JOIN stats s
WHERE t.[duration] < (s.Q1 - 1.5 * (s.Q3 - s.Q1))
   OR t.[duration] > (s.Q3 + 1.5 * (s.Q3 - s.Q1));


------deal with nulls
alter table [dbo].[spotify_songs_dataset]
drop column[collaboration];



select * from [dbo].[spotify_songs_dataset]

update [dbo].[spotify_songs_dataset]
set [duration] = (
        select cast(avg([duration]) as int)
        from [dbo].[spotify_songs_dataset]
        )
where [duration] is null


update [dbo].[spotify_songs_dataset]
set [language] = (
        select
            top 1 [language]
        from 
            [dbo].[spotify_songs_dataset]
        where 
            [language] is not null
        )
where [language] is null


select *
from
    [dbo].[spotify_songs_dataset]
where
    [song_id] is null
    or [song_title] is null
    or [artist] is null
    or [album] is null
    or [genre] is null
    or [release_date] is null
    or [duration] is null
    or [popularity] is null
    or [stream] is null
    or [language] is null
    or [explicit_content] is null
    or [label] is null
    or [language] is null 
    or [duration] is null

-------adding columns
---adding [streams_level]

select min([stream]) , max([stream])
from 
    [dbo].[spotify_songs_dataset];
alter table [dbo].[spotify_songs_dataset]
add [streams_level] varchar(10);

update [dbo]. [spotify_songs_dataset]
set [streams_level] = case
                            when [stream] <= 25000000 then 'Low'
                            when [stream] <= 50000000 then'medium'
                            when [stream] <= 75000000 then 'High'
                            else 'Very High'
                      end;

---adding [popularity_level]

select min([popularity]),max([popularity])
from [dbo].[spotify_songs_dataset];

alter table [dbo]. [spotify_songs_dataset] 
add [popularity_level] varchar(10);

---adding [duration_minute]
select min([duration]),max([duration]) from [dbo].[spotify_songs_dataset];
--cast duration as minute
select convert(decimal(10,2) , [duration] /60) 
from [dbo].[spotify_songs_dataset]

update [dbo].[spotify_songs_dataset]
set [duration] = convert(decimal(10,2) , [duration] /60) 

alter table [dbo].[spotify_songs_dataset]
add [duration_minute] varchar(20);

update [dbo].[spotify_songs_dataset]
set [duration_minute] = case 
                    when [duration] <3 then 'short'
                    when [duration] < 4.5 then 'normal'
                    when [duration] >= 4.5then 'long'
                end;

-----adding [date_category]
select 
    year(min([release_date])) , year(max([release_date]))
from [dbo].[spotify_songs_dataset];

alter table [dbo].[spotify_songs_dataset]
add [date_group] varchar(20);

update [dbo].[spotify_songs_dataset]
set [date_group] = case 
                        when year([release_date]) < 2005 then 'old'
                        when year([release_date]) < 2015 then 'middle'
                        when year([release_date]) >= 2015 then 'new'
                    end;
select [date_group]
from [dbo].[spotify_songs_dataset]
where [date_group] is null;




-- ================ Insights
----- top 10 songs
SELECT TOP 10 [song_title], [artist], [popularity]
FROM [dbo].[spotify_songs_dataset]
ORDER BY [popularity] DESC;

--  Top 10 songs
SELECT TOP 10 [song_title], [artist], [stream]
FROM [dbo].[spotify_songs_dataset]
ORDER BY [stream] DESC;

-- Genre with popularity level counts

SELECT *
FROM (
    SELECT [genre], [popularity_level]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    COUNT([popularity_level])
    FOR [popularity_level] IN ([high], [Medium], [Low])
) AS pvt;


-- Genre with popularity level & avg streams

WITH GenreAvg AS (
    SELECT [genre],
           AVG(CAST([stream] AS FLOAT)) AS avg_genre_stream
    FROM [dbo].[spotify_songs_dataset]
    GROUP BY [genre]
)
SELECT pvt.[genre], pvt.[high], pvt.[Medium], pvt.[Low], g.avg_genre_stream
FROM (
    SELECT [genre], [popularity_level], CAST([stream] AS FLOAT) AS [stream]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([stream])
    FOR [popularity_level] IN ([high], [Medium], [Low])
) AS pvt
JOIN GenreAvg g ON pvt.[genre] = g.[genre]
ORDER BY pvt.[genre];


-- Explicit vs Non-Explicit popularity

SELECT *
FROM (
    SELECT 
        CASE WHEN [explicit_content] = 1 THEN 'Explicit'
             ELSE 'NonExplicit'
        END AS [explicit_flag],
        CAST([popularity] AS FLOAT) AS [popularity]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([popularity])
    FOR [explicit_flag] IN ([Explicit],[NonExplicit])
) AS pvt;


-- Top 2 years by number of releases

SELECT TOP 2 YEAR([release_date]) AS release_year,
       COUNT([song_id]) AS num_releases
FROM [dbo].[spotify_songs_dataset]
WHERE YEAR([release_date]) BETWEEN 1994 AND 2025
GROUP BY YEAR([release_date])
ORDER BY COUNT([song_id]) DESC;


-- Average streams by date_group
SELECT *
FROM (
    SELECT [date_group],
           CAST([stream] AS FLOAT) AS [stream]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([stream])
    FOR [date_group] IN ([new],[middle],[old])
) AS pvt;


-- Count of songs per language

SELECT *
FROM (
    SELECT [language]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    COUNT([language])
    FOR [language] IN ([English],[Japanese],[German],[French],[Spanish],[Italian],[Korean])
) AS pvt;


-- Average popularity by language

SELECT *
FROM (
    SELECT [language], [popularity]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([popularity])
    FOR [language] IN ([English],[Japanese],[German],[French],[Spanish],[Italian],[Korean])
) AS pvt;


-- Popularity by duration level

SELECT *
FROM (
    SELECT [duration_minute],
           CAST([popularity] AS FLOAT) AS [popularity]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([popularity])
    FOR [duration_minute] IN ([short],[normal],[long])
) AS pvt;


-- Streams by duration level

SELECT *
FROM (
    SELECT [duration_minute],
           CAST([stream] AS FLOAT) AS [stream]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([stream])
    FOR [duration_minute] IN ([short],[normal],[long])
) AS pvt;


-- Count of songs by duration vs popularity level

SELECT *
FROM (
    SELECT [duration_minute], [popularity_level]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    COUNT([duration_minute])
    FOR [duration_minute] IN ([normal],[short],[long])
) AS pvt;


-- Count of songs by duration vs streams level

SELECT *
FROM (
    SELECT [duration_minute], [streams_level]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    COUNT([streams_level])
    FOR [streams_level] IN ([Low],[Medium],[High])
) AS pvt;


--Explicit content count by streams level

SELECT *
FROM (
    SELECT [streams_level],
           [explicit_content]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    COUNT([explicit_content])
    FOR [streams_level] IN ([Low],[Medium],[High])
) AS pvt;


-- Explicit content count by date group

SELECT *
FROM (
    SELECT [date_group],
           [explicit_content]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    COUNT([explicit_content])
    FOR [date_group] IN ([new],[middle],[old])
) AS pvt;


-- Count of songs by duration_minute and date_group

SELECT *
FROM (
    SELECT [duration_minute], [date_group]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    COUNT([date_group])
    FOR [date_group] IN ([new],[middle],[old])
) AS pvt;


-- Average popularity by duration_minute and explicit content

SELECT *
FROM (
    SELECT [duration_minute],
           CASE WHEN [explicit_content] = 1 THEN 'Explicit' ELSE 'NonExplicit' END AS exp_flag,
           CAST([popularity] AS FLOAT) AS [popularity]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([popularity])
    FOR exp_flag IN ([Explicit],[NonExplicit])
) AS pvt;


-- Average streams by genre and date_group

SELECT *
FROM (
    SELECT [genre], [date_group], CAST([stream] AS FLOAT) AS [stream]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([stream])
    FOR [date_group] IN ([new],[middle],[old])
) AS pvt;


-- Count of songs by popularity_level and explicit content

SELECT *
FROM (
    SELECT [popularity_level],
           CASE WHEN [explicit_content] = 1 THEN 'Explicit' ELSE 'NonExplicit' END AS exp_flag
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    COUNT(exp_flag)
    FOR exp_flag IN ([Explicit],[NonExplicit])
) AS pvt;


-- Average streams by language and popularity_level

SELECT *
FROM (
    SELECT [language], [popularity_level], CAST([stream] AS FLOAT) AS [stream]
    FROM [dbo].[spotify_songs_dataset]
) AS src
PIVOT (
    AVG([stream])
    FOR [popularity_level] IN ([Low],[Medium],[High])
) AS pvt;
