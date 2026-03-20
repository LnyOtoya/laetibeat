package com.otimeum.laetibeat.ui.screens.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.otimeum.laetibeat.model.Track
import com.otimeum.laetibeat.repository.MusicRepository
import com.otimeum.laetibeat.ui.components.TrackItem

/**
 * 音乐库屏幕
 */
@Composable
fun LibraryScreen(
    onPlayTrack: (Track) -> Unit,
    onNavigateToNowPlaying: () -> Unit
) {
    val surfaceColor = MaterialTheme.colorScheme.surface
    val primaryColor = MaterialTheme.colorScheme.primary
    val secondaryColor = MaterialTheme.colorScheme.secondary
    val tertiaryColor = MaterialTheme.colorScheme.tertiary
    
    val musicRepository = MusicRepository()
    val (tracks, setTracks) = remember { mutableStateOf(emptyList<Track>()) }
    val (albums, setAlbums) = remember { mutableStateOf(emptyList<Album>()) }
    val (artists, setArtists) = remember { mutableStateOf(emptyList<Artist>()) }
    val playlists = getPlaylists()
    
    LaunchedEffect(Unit) {
        val loadedTracks = musicRepository.getTracks()
        setTracks(loadedTracks)
        setAlbums(getAlbums(loadedTracks))
        setArtists(getArtists(loadedTracks))
    }

    var selectedTab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Songs", "Albums", "Artists", "Playlists")

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .drawBehind {
                drawRect(surfaceColor)
            }
    ) {
        // 顶部标题
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text(
                text = "Your Library",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )
        }

        // 标签栏
        TabRow(
            selectedTabIndex = selectedTab,
            modifier = Modifier.fillMaxWidth()
        ) {
            tabs.forEachIndexed { index, title ->
                Tab(
                    selected = selectedTab == index,
                    onClick = { selectedTab = index },
                    text = {
                        Text(
                            text = title,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                )
            }
        }

        // 标签内容
        when (selectedTab) {
            0 -> SongsTab(tracks, onPlayTrack)
            1 -> AlbumsTab(albums)
            2 -> ArtistsTab(artists)
            3 -> PlaylistsTab(playlists)
        }
    }
}

/**
 * 歌曲标签页
 */
@Composable
fun SongsTab(
    tracks: List<Track>,
    onPlayTrack: (Track) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(tracks) {
            TrackItem(
                track = it,
                isPlaying = false, // 这里应该根据实际播放状态设置
                onTrackClick = onPlayTrack
            )
        }
    }
}

/**
 * 专辑标签页
 */
@Composable
fun AlbumsTab(
    albums: List<Album>
) {
    LazyRow(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        items(albums) {
            AlbumCard(album = it)
        }
    }
}

/**
 * 艺术家标签页
 */
@Composable
fun ArtistsTab(
    artists: List<Artist>
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(artists) {
            ArtistItem(artist = it)
        }
    }
}

/**
 * 播放列表标签页
 */
@Composable
fun PlaylistsTab(
    playlists: List<Playlist>
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(playlists) {
            PlaylistItem(playlist = it)
        }
    }
}

/**
 * 专辑卡片
 */
@Composable
fun AlbumCard(
    album: Album
) {
    val primaryColor = MaterialTheme.colorScheme.primary
    Card(
        modifier = Modifier
            .size(180.dp, 240.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // 封面占位
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .clip(RoundedCornerShape(12.dp))
                    .drawBehind {
                        drawRect(primaryColor.copy(alpha = 0.2f))
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "A",
                    fontSize = 48.sp,
                    color = primaryColor,
                    fontWeight = FontWeight.Bold
                )
            }
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = album.name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1
                )
                Text(
                    text = album.artist,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
                Text(
                    text = "${album.trackCount} songs",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

/**
 * 艺术家项
 */
@Composable
fun ArtistItem(
    artist: Artist
) {
    val secondaryColor = MaterialTheme.colorScheme.secondary
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(4.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // 头像占位
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(24.dp))
                            .drawBehind {
                                drawRect(secondaryColor.copy(alpha = 0.2f))
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = artist.name.first().toString(),
                            fontSize = 20.sp,
                            color = secondaryColor,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Text(
                        text = artist.name,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium
                    )
                }
                Text(
                    text = "${artist.albumCount} albums",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

/**
 * 播放列表项
 */
@Composable
fun PlaylistItem(
    playlist: Playlist
) {
    val tertiaryColor = MaterialTheme.colorScheme.tertiary
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(4.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // 封面占位
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .drawBehind {
                                drawRect(tertiaryColor.copy(alpha = 0.2f))
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "P",
                            fontSize = 20.sp,
                            color = tertiaryColor,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Text(
                        text = playlist.name,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium
                    )
                }
                Text(
                    text = "${playlist.trackCount} songs",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

/**
 * 专辑数据类
 */
data class Album(
    val id: String,
    val name: String,
    val artist: String,
    val trackCount: Int
)

/**
 * 艺术家数据类
 */
data class Artist(
    val id: String,
    val name: String,
    val albumCount: Int
)

/**
 * 播放列表数据类
 */
data class Playlist(
    val id: String,
    val name: String,
    val trackCount: Int
)

// 模拟数据生成
fun getAlbums(tracks: List<Track>): List<Album> {
    val albumMap = mutableMapOf<String, Album>()
    tracks.forEach {
        val key = "${it.album}-${it.artist}"
        if (!albumMap.containsKey(key)) {
            albumMap[key] = Album(
                id = key,
                name = it.album,
                artist = it.artist,
                trackCount = 1
            )
        } else {
            val album = albumMap[key]!!
            albumMap[key] = album.copy(trackCount = album.trackCount + 1)
        }
    }
    return albumMap.values.toList()
}

fun getArtists(tracks: List<Track>): List<Artist> {
    val artistMap = mutableMapOf<String, Artist>()
    tracks.forEach {
        if (!artistMap.containsKey(it.artist)) {
            artistMap[it.artist] = Artist(
                id = it.artist,
                name = it.artist,
                albumCount = 1
            )
        } else {
            val artist = artistMap[it.artist]!!
            artistMap[it.artist] = artist.copy(albumCount = artist.albumCount + 1)
        }
    }
    return artistMap.values.toList()
}

fun getPlaylists(): List<Playlist> {
    return listOf(
        Playlist("1", "My Favorites", 10),
        Playlist("2", "Workout Mix", 8),
        Playlist("3", "Chill Vibes", 12),
        Playlist("4", "Party Time", 15),
        Playlist("5", "Focus", 6)
    )
}
