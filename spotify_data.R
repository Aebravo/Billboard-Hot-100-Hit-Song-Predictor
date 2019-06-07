rm(list = ls())
cat('\014')

library(tidyverse)
library(jsonlite)
library(rvest)
library(geniusR) # to get genius song lyrics
library(reshape2)
library(magrittr)
library(devtools)
library(Rspotify)


CLIENT_ID_spotify <- 'fc2dd4276b344164969c6d67338e082b'
CLIENT_SECRET_spotify <- 'ddc243b034de4d9b924bac51caf48c32'
APP_ID_spotify <- 'Song analyzer'

spotify_keys <- spotifyOAuth(APP_ID_spotify, CLIENT_ID_spotify, CLIENT_SECRET_spotify)


top_artists <- read_html('https://kworb.net/spotify/artists.html') %>% html_table() %>% .[[1]] %>% select(Artist) # select the top 10000 spotify artists
top_artists %<>% mutate(Artist = str_replace_all(Artist, pattern = ' ', replacement = '+')) %>% distinct()


spotify_info <- data_frame()
for(i in 1:nrow(top_artists)) {
  print(paste0(i, ' / ', nrow(top_artists)))
  try(temp_df <- as_data_frame(searchArtist(top_artists$Artist[i], token=spotify_keys)) %>%  slice(1))
  spotify_info <- bind_rows(spotify_info, temp_df)
} # get spotify artist info

test <- as_data_frame(getAlbums("6eUKZXaKkcviH0Ku9w2n3V", token = spotify_keys)) %>% distinct(name, .keep_all = T) 
as_data_frame(getAlbumInfo("1ATL5GLyefJaxhQzSPVrLX", token = spotify_keys))

albums <- data_frame()
for(i in 1:nrow(top_artists)) {
  print(paste0(i, ' / ', nrow(spotify_info)))
  try(temp_df <- as_data_frame(getAlbums(spotify_info$id[i], token = spotify_keys, type = "album")))
  albums <- bind_rows(albums, temp_df)
} # get all albums by each artist that are on spotify
albums %<>% distinct()

album_info <- data_frame()
for(i in 1:nrow(albums)) {
  print(paste0(i, ' / ', nrow(albums)))
  try(temp_df <- as_data_frame(getAlbumInfo(albums$id[i], token = spotify_keys)))
  album_info <- bind_rows(album_info, temp_df)
} # collect album info for each album in albums df

album_info %<>% group_by(artist, name) %>% top_n(n = 1, popularity) %>% distinct() # select the most popular release of each artist's albums

album_info %<>% group_by(artist) %>% top_n(n = 5, popularity) # select the top 5 albums for each artist by popularity score


songs <- data_frame()
for(i in 1:nrow(album_info)) {
  print(paste0(i, ' / ', nrow(album_info)))
  try(temp_df <- getAlbum(album_info$id[i], token = spotify_keys) %>% mutate(artist = album_info$artist[i], album = album_info$name[i], album_popularity = album_info$popularity[i]))
  songs <- bind_rows(songs, temp_df)
}


songs$lyrics <- c()
for(i in 1:nrow(songs)) {
  print(paste0(i, ' / ', nrow(songs)))
  lyrics <- tryCatch({ genius_lyrics(songs$artist[i], songs$name[i]) %>% select(lyric)},
                     error = function(err) { return("") })
  songs$lyrics[i] <- lyrics
} # get lyrics for each song

test <- as_data_frame(getFeatures("6RUKPb4LETWmmr3iAEQktW", token=spotify_keys))

# create new tidy_songs df to manipulate songs df 
tidy_songs <- songs %>% 
  filter(lyrics != "")

tidy_songs <- tidy_songs %>% 
  left_join(spotify_info, by = c('artist' = 'display_name')) %>% 
  select(-c(id.y, type, available_markets)) %>% 
  rename(track_id = id.x) 

tidy_songs <- tidy_songs %>% 
  mutate(track_id = as.character(track_id),
         name = as.character(name),
         duration_ms = as.numeric(duration_ms),
         track_number = as.numeric(track_number),
         disc_number = as.numeric(disc_number),
         preview_url = as.character(preview_url))


for(i in 1:nrow(tidy_songs)) {
  tidy_songs$lyrics[i] <- paste(tidy_songs$lyrics[[i]], collapse = " ") 
} # convert lyrics to one character string

tidy_songs <- tidy_songs %>% 
  mutate(lyrics = as.character(lyrics))

song_features <- data_frame()
for(i in 1:nrow(tidy_songs)) {
  print(paste0(i, ' / ', nrow(tidy_songs)))
  temp_df <- tryCatch({ as_data_frame(getFeatures(tidy_songs$track_id[i], token = spotify_keys)) },
                      error = function(err) { return(data_frame(id = tidy_songs$track_id[i])) })
  song_features <- bind_rows(song_features, temp_df)
} # get song feature data

## add song features to tidy_songs
tidy_songs <- tidy_songs %>% 
  left_join(song_features, by = c('track_id' = 'id')) %>% 
  select(-c(uri, analysis_url, duration_ms.y, track_number, disc_number)) %>% 
  rename(artist_popularity = popularity, artist_followers = followers, duration_ms = duration_ms.x, song_title = name) 

tidy_songs <- tidy_songs %>% distinct(song_title, .keep_all = T) %>% filter(song_title != "") %>% filter(preview_url != 'list()') # remove duplicate rows

tidy_songs %>% count(artist, sort = T)

# write_tsv(tidy_songs, 'spotify-song-data.tsv')



music_path <- file.path(getwd(), 'mp3-data')
tidy_songs$mp3_file <- ''
for(i in 1:nrow(tidy_songs)) {
  print(paste(i, '/', nrow(tidy_songs))) # first 10000 songs
  try(download.file(tidy_songs$preview_url[i], file.path(music_path, paste0(tidy_songs$track_id[i], '.mp3'))))
  tidy_songs$mp3_file[i] <- file.path(music_path, paste0(tidy_songs$track_id[i], '.mp3'))
}

getCategories <- function() {
  req <- httr::content(httr::GET(paste0("https://api.spotify.com/v1/browse/categories?country=US&limit=50"),
                                 httr::config(token = spotify_keys)))
  categories <- req$categories$items
  catergories.df <- dplyr::bind_rows(
    lapply(categories, function(x) data.frame(
      id = x$id, name = x$name, href = x$href,
      stringsAsFactors = FALSE)))
  return(catergories.df)
} # retunrs a data frame with all of spotify's unique categories

genres <- c('hiphop', 'rnb', 'rock', 'country', 'edm_dance', 'indie_alt', 'classical', 'jazz', 'desi', 'kpop', 'metal', 'soul', 'blues', 'punk', 'funk')
categories <- getCategories() %>% filter(id %in% genres)

getCategoryPlaylists <- function(category_id) {
  req <- httr::content(httr::GET(paste0("https://api.spotify.com/v1/browse/categories/", category_id, "/playlists?limit=30"),
                                 httr::config(token = spotify_keys)))
  playlists <- req$playlists$items
  playlists.df <- dplyr::bind_rows(
    lapply(playlists, function(x) data.frame(
      id = x$id, name = x$name, href = x$href,
      owner_id = x$owner$id, genre = category_id,
      stringsAsFactors = FALSE)))
  return(playlists.df)
} # get playlists belonging to a category

allGenres_Playlists <- data_frame()
for(i in 1:length(genres)) {
  allGenres_Playlists <- bind_rows(allGenres_Playlists, getCategoryPlaylists(genres[i])) 
} # create a df with playlists from all genres

getGenreTracks <- function(a_genre) {
  playlist_df <- allGenres_Playlists %>% filter(genre == a_genre)
  tracks <- data_frame()
  for(i in 1:nrow(playlist_df)) {
    print(paste0('Genre: ', a_genre, " --> ", i, '/', nrow(playlist_df)))
    try(tracks <- bind_rows(tracks, getPlaylistSongs(playlist_df$owner_id[i], playlist_df$id[i], token = spotify_keys)))
  }
  tracks$genre <- a_genre
  tracks %<>% distinct(id, .keep_all = T)
  return(tracks)
} # get all tracks for a genre

all_tracks <- data_frame()
for(i in 1:length(genres)) {
  print(paste0('Genre: ', genres[i], ' ', i, '/', length(genres)))
  temp_df <- getGenreTracks(genres[i])
  all_tracks <- bind_rows(all_tracks, temp_df)
} # collect all tracks for every genre
all_tracks <- all_tracks %>% distinct(id, .keep_all = T) 


features <- data_frame()
for(i in 1:nrow(all_tracks)) {
  print(paste0(i, '/', nrow(all_tracks)))
  try(temp_df <- getFeatures(all_tracks$id[i], token = spotify_keys))
  features <- bind_rows(features, temp_df)
} # returns a data frame with features for each track in all_tracks

all_tracks <- all_tracks %>% 
  inner_join(features, by = c('id' = 'id')) %>% 
  rename(track_id = id, track = tracks)

getPreviewURL <- function(track_id) {
  req <- httr::content(httr::GET(paste0("https://api.spotify.com/v1/tracks/", track_id),
                                 httr::config(token = spotify_keys)))
  preview_url.df <- data_frame(track_id = req$id, preview_url = req$preview_url)
  return(preview_url.df)
} # returns a track id and it's preview url


# getPreviewURL(all_tracks$track_id[1])
preview_url.df <- data_frame()
for(i in 1:nrow(all_tracks)) {
  print(paste0(i, '/', nrow(all_tracks)))
  try(temp_df <- getPreviewURL(all_tracks$track_id[i]))
  preview_url.df <- bind_rows(preview_url.df, temp_df)
} # returns a df with the preview url for each track_id in all_tracks
preview_url.df <- preview_url.df %>% distinct(preview_url, .keep_all = T)

all_tracks <- all_tracks %>% inner_join(preview_url.df, by = c('track_id' = 'track_id'))

genre_track_counts <- all_tracks %>% 
  group_by(genre) %>% 
  summarise(totals = n())

all_tracks$mp3_path <- ''
downloadMP3File <- function(track_id, preview_url) {
  tryCatch({ mp3Path <- file.path(getwd(), 'mp3-files', track_id)
  download.file(preview_url, destfile = mp3Path)
  return(paste0(mp3Path, '.wav'))
  }, error = function(err) {
    return('FNF')
  })
}

# test <- all_tracks %>% slice(1:30)
for(i in 1:nrow(all_tracks)) {
  print(paste(i, '/', nrow(all_tracks)))
  all_tracks$mp3_path[i] <- downloadMP3File(all_tracks$track_id[i], all_tracks$preview_url[i])
} # downloads preview mp3 files for each track in all_tracks and adds the local path to the mp3 preview to all_tracks

tidy_all_tracks <- all_tracks %>% select(-c(uri, analysis_url))
# write_tsv(tidy_all_tracks, "all_tracks.tsv")
lyrics.df <- tidy_all_tracks %>% 
  mutate(track = str_remove_all(track, pattern = regex('[[:punct:]]')))
lyrics.df <- lyrics.df %>% 
  mutate(track = str_remove(track, patter = 'feat..*'))


get_track_lyrics <- function(i) { tryCatch({
  paste(c(genius_lyrics(lyrics.df$artist[i], song = lyrics.df$track[i]) %>% select(lyric))[[1]], collapse = " ")
}, error = function(err) {
  return('track lyrics not found')
})
} # returns the lyrics for a song in the tidy_all_tracks data frame. parameter is the index of tidy_all_tracks

# test <- tidy_all_tracks %>% slice(1:5)
tidy_all_tracks$lyrics <- ''
for(i in 1:nrow(tidy_all_tracks)) {
  print(paste0(i, '/', nrow(tidy_all_tracks)))
  tidy_all_tracks$lyrics[i] <- get_track_lyrics(i) 
}  
tidy_all_tracks <- tidy_all_tracks %>% 
  mutate(mp3_path = paste0(mp3_path, '.wav'))

tidy_all_lyrics_tracks <- tidy_all_tracks %>% 
  filter(lyrics != 'track lyrics not found')

write_tsv(tidy_all_tracks, "all_tracks_lyrics.tsv")
write_tsv(tidy_all_tracks %>% select(-lyrics), 'all_tracks.tsv')

# music_files <- list.files('mp3-files')
# new_music_files <- paste0(music_files, '.wav')
# file.path(new_music_files)
# setwd(file.path(getwd(), 'mp3-files'))
# getwd()
# file.rename(music_files, new_music_files)
