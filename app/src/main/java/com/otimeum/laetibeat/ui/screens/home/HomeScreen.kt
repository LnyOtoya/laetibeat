package com.otimeum.laetibeat.ui.screens.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.clickable
import com.otimeum.laetibeat.model.Track
import com.otimeum.laetibeat.repository.MusicRepository
import com.otimeum.laetibeat.ui.components.TrackItem
import kotlinx.coroutines.launch

/**
 * 首页屏幕
 */
@Composable
fun HomeScreen(
    onPlayTrack: (Track) -> Unit,
    onNavigateToNowPlaying: () -> Unit
) {
    val surfaceColor = MaterialTheme.colorScheme.surface
    val primaryColor = MaterialTheme.colorScheme.primary
    val secondaryColor = MaterialTheme.colorScheme.secondary
    val tertiaryColor = MaterialTheme.colorScheme.tertiary
    
    val musicRepository = MusicRepository()
    val (tracks, setTracks) = remember { mutableStateOf(emptyList<Track>()) }
    
    LaunchedEffect(Unit) {
        val loadedTracks = musicRepository.getTracks()
        setTracks(loadedTracks)
    }
    
    val recentTracks = tracks.take(4)
    val recommendedTracks = tracks.take(6)

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .drawBehind {
                drawRect(surfaceColor)
            },
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        // 顶部问候
        item {
            Column(
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "Good morning",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Let's enjoy some music",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // 最近播放
        item {
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Recently Played",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(recentTracks) {
                        RecentPlayCard(track = it, onPlay = { onPlayTrack(it) })
                    }
                }
            }
        }

        // 推荐内容
        item {
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Recommended for you",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(recommendedTracks) {
                        RecommendedCard(track = it, onPlay = { onPlayTrack(it) })
                    }
                }
            }
        }

        // 为你精选
        item {
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Featured",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(tracks.takeLast(4)) {
                        FeaturedCard(track = it, onPlay = { onPlayTrack(it) })
                    }
                }
            }
        }
    }
}

/**
 * 最近播放卡片
 */
@Composable
fun RecentPlayCard(
    track: Track,
    onPlay: () -> Unit
) {
    val primaryColor = MaterialTheme.colorScheme.primary
    Card(
        modifier = Modifier
            .size(160.dp, 200.dp)
            .clickable { onPlay() },
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
                    text = "M",
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
                    text = track.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1
                )
                Text(
                    text = track.artist,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
            }
        }
    }
}

/**
 * 推荐卡片
 */
@Composable
fun RecommendedCard(
    track: Track,
    onPlay: () -> Unit
) {
    val secondaryColor = MaterialTheme.colorScheme.secondary
    Card(
        modifier = Modifier
            .size(140.dp, 180.dp)
            .clickable { onPlay() },
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // 封面占位
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .drawBehind {
                        drawRect(secondaryColor.copy(alpha = 0.2f))
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "M",
                    fontSize = 36.sp,
                    color = secondaryColor,
                    fontWeight = FontWeight.Bold
                )
            }
            Column(
                modifier = Modifier.padding(10.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = track.title,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1
                )
                Text(
                    text = track.artist,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
            }
        }
    }
}

/**
 * 精选卡片
 */
@Composable
fun FeaturedCard(
    track: Track,
    onPlay: () -> Unit
) {
    val tertiaryColor = MaterialTheme.colorScheme.tertiary
    Card(
        modifier = Modifier
            .size(180.dp, 220.dp)
            .clickable { onPlay() },
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
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
                        drawRect(tertiaryColor.copy(alpha = 0.2f))
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "M",
                    fontSize = 56.sp,
                    color = tertiaryColor,
                    fontWeight = FontWeight.Bold
                )
            }
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = track.title,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1
                )
                Text(
                    text = track.artist,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
                Text(
                    text = track.album,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
            }
        }
    }
}
