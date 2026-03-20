package com.otimeum.laetibeat.ui.screens.search

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SearchBar
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import com.otimeum.laetibeat.model.Track
import com.otimeum.laetibeat.repository.MusicRepository
import com.otimeum.laetibeat.ui.components.TrackItem

/**
 * 搜索屏幕
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    onPlayTrack: (Track) -> Unit,
    onNavigateToNowPlaying: () -> Unit
) {
    val surfaceColor = MaterialTheme.colorScheme.surface
    
    var searchQuery by remember { mutableStateOf("") }
    val musicRepository = MusicRepository()
    val (tracks, setTracks) = remember { mutableStateOf(emptyList<Track>()) }
    
    LaunchedEffect(Unit) {
        val loadedTracks = musicRepository.getTracks()
        setTracks(loadedTracks)
    }
    
    val searchResults = if (searchQuery.isNotEmpty()) {
        tracks.filter { 
            it.title.lowercase().contains(searchQuery.lowercase()) ||
            it.artist.lowercase().contains(searchQuery.lowercase()) ||
            it.album.lowercase().contains(searchQuery.lowercase())
        }
    } else {
        emptyList()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .drawBehind {
                drawRect(surfaceColor)
            }
    ) {
        // 搜索栏
        SearchBar(
            query = searchQuery,
            onQueryChange = { searchQuery = it },
            onSearch = { /* 处理搜索 */ },
            active = false,
            onActiveChange = { /* 处理激活状态 */ },
            placeholder = { Text("Search for songs, artists, or albums") },
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            // 搜索建议（可选）
        }

        if (searchQuery.isEmpty()) {
            // 分类浏览
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                // 热门搜索
                item {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "Top Searches",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(topSearches) {
                                SearchChip(text = it)
                            }
                        }
                    }
                }

                // 音乐分类
                item {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "Categories",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                        LazyVerticalGrid(
                            columns = GridCells.Fixed(2),
                            horizontalArrangement = Arrangement.spacedBy(16.dp),
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            items(categories) {
                                CategoryCard(category = it)
                            }
                        }
                    }
                }

                // 最近搜索
                item {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "Recent Searches",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                        Column(
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            recentSearches.forEach {
                                RecentSearchItem(text = it)
                            }
                        }
                    }
                }
            }
        } else {
            // 搜索结果
            if (searchResults.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No results found for \"$searchQuery\"",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    item {
                        Text(
                            text = "Search results for \"$searchQuery\"",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    items(searchResults) {
                        TrackItem(
                            track = it,
                            isPlaying = false, // 这里应该根据实际播放状态设置
                            onTrackClick = onPlayTrack
                        )
                    }
                }
            }
        }
    }
}

/**
 * 搜索芯片
 */
@Composable
fun SearchChip(
    text: String
) {
    Card(
        modifier = Modifier
            .padding(4.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        shape = RoundedCornerShape(20.dp)
    ) {
        Box(
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

/**
 * 分类卡片
 */
@Composable
fun CategoryCard(
    category: Category
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1.5f),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        shape = RoundedCornerShape(16.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(16.dp))
                .drawBehind {
                    drawRect(category.color)
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = category.name,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }
    }
}

/**
 * 最近搜索项
 */
@Composable
fun RecentSearchItem(
    text: String
) {
    Card(
        modifier = Modifier
            .fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

/**
 * 分类数据类
 */
data class Category(
    val name: String,
    val color: Color
)

// 模拟数据
val topSearches = listOf(
    "Shape of You",
    "Blinding Lights",
    "Dance Monkey",
    "Levitating",
    "Save Your Tears"
)

val categories = listOf(
    Category("Pop", Color(0xFF4A6CF7)),
    Category("Rock", Color(0xFFF74A4A)),
    Category("Hip Hop", Color(0xFF4AF7A8)),
    Category("Electronic", Color(0xFFF7D44A)),
    Category("Classical", Color(0xFFA44AF7)),
    Category("Jazz", Color(0xFF4AAFF7))
)

val recentSearches = listOf(
    "Ed Sheeran",
    "The Weeknd",
    "Dua Lipa",
    "Olivia Rodrigo"
)
