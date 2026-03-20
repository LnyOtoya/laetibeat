package com.otimeum.laetibeat.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.otimeum.laetibeat.model.PlayerStatus
import com.otimeum.laetibeat.model.Track

/**
 * 迷你播放器组件
 */
@Composable
fun MiniPlayer(
    currentTrack: Track?,
    status: PlayerStatus,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onNavigateToNowPlaying: () -> Unit
) {
    if (currentTrack == null) return
    
    val surfaceColor = MaterialTheme.colorScheme.surface
    val primaryColor = MaterialTheme.colorScheme.primary
    val onPrimaryColor = MaterialTheme.colorScheme.onPrimary
    val surfaceVariantColor = MaterialTheme.colorScheme.surfaceVariant

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp)
            .clickable { onNavigateToNowPlaying() },
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        colors = CardDefaults.cardColors(
            containerColor = surfaceColor
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // 小封面
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .drawBehind {
                        drawRect(primaryColor.copy(alpha = 0.2f))
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "M",
                    fontSize = 24.sp,
                    color = primaryColor,
                    fontWeight = FontWeight.Bold
                )
            }

            // 歌曲信息
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = currentTrack.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1
                )
                Text(
                    text = currentTrack.artist,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
            }

            // 控制按钮
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IconButton(onClick = onPlayPause) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .drawBehind {
                                drawRect(primaryColor)
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = if (status == PlayerStatus.PLAYING) "⏸" else "▶",
                            fontSize = 16.sp,
                            color = onPrimaryColor
                        )
                    }
                }

                IconButton(onClick = onNext) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .drawBehind {
                                drawRect(surfaceVariantColor)
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "⏭",
                            fontSize = 16.sp
                        )
                    }
                }
            }
        }
    }
}
