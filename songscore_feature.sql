create database billboard;

Create table full_billboard(track_id varchar(100), track_title varchar(500), popularity decimal,\
 explicit bool, duration_ms decimal, preview_url varchar(500), artist_title varchar(500), \
 artist_id varchar(100), album_id varchar(100), album_type varchar(100), album_release_date decimal, \
 album_release_date_precision varchar(100), trackId varchar(100), acousticness decimal, \
 danceability decimal, energy decimal, instrumentalness decimal, key decimal, liveliness decimal, \
 loudness decimal, mode decimal, speechless decimal, tempo decimal, time_signature decimal, \
 valence decimal, billboard_title varchar(100), billboard_artist varchar(100), \
 billboard_peakPos decimal, billboard_lastPos decimal, billboard_weeks decimal, \
 billboard_rank decimal, billboard_isNew bool, billboard_date decimal, billboard_name varchar(100), \
 billboard_hit decimal);

//deleted last 3 songs in CSV file to upload (They were in our target time period and were providing several issues

//modify with your own file path
copy full_billboard from '/Users/angelobravo/Downloads/spotify_billboard.csv' delimiter ',' CSV HEADER;

create table positions_with_times(songtitle varchar(100), artist varchar(100), peakPos int, \
lastPos int, weeks int, rank int, isnew bool, timestamp date, name varchar(100)); 

copy positions_with_times from '/Users/angelobravo/Downloads/Billboard_Hit_Prediction-master/data/billboard_df.csv' delimiter ',' CSV HEADER;

UPDATE full_billboard SET track_title = LOWER(track_title);

UPDATE full_billboard SET artist_title = LOWER(artist_title);
 
Create table newtable1 as select songtitle, artist, 1/cast(rank as decimal) as metric from positions_with_times;

create table metrictable as select songtitle, artist, sum(metric) as metric from newtable1 group by songtitle, artist;

UPDATE metrictable SET songtitle = LOWER(songtitle);

UPDATE metrictable SET artist = LOWER(artist);

create table billboard_with_songscore as select track_title, artist_title, explicit,\
 duration_ms, acousticness, danceability, energy, instrumentalness, key, liveliness,\
  loudness, mode, speechiness, tempo, time_signature, valence, metric, \
  billboard_hit from full_billboard left join metrictable on track_title = songtitle and artist_title = artist;


COPY billboard_with_songscore to '/Users/angelobravo/Downloads/billboard_songscores.csv' delimiters ',' \
with (format csv, header);

