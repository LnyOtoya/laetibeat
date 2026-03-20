package com.otimeum.laetibeat.repository

import com.otimeum.laetibeat.model.Track

/**
 * 音乐仓库
 * 目前使用假数据，未来可替换为真实后端API
 */
class MusicRepository {
    /**
     * 获取歌曲列表
     */
    suspend fun getTracks(): List<Track> {
        // 模拟网络延迟
        kotlinx.coroutines.delay(500)
        
        // 提供假数据
        return listOf(
            Track(
                id = "1",
                title = "Shape of You",
                artist = "Ed Sheeran",
                album = "÷ (Divide)",
                duration = 233
            ),
            Track(
                id = "2",
                title = "Blinding Lights",
                artist = "The Weeknd",
                album = "After Hours",
                duration = 203
            ),
            Track(
                id = "3",
                title = "Dance Monkey",
                artist = "Tones and I",
                album = "The Kids Are Coming",
                duration = 229
            ),
            Track(
                id = "4",
                title = "Don't Start Now",
                artist = "Dua Lipa",
                album = "Future Nostalgia",
                duration = 203
            ),
            Track(
                id = "5",
                title = "Levitating",
                artist = "Dua Lipa",
                album = "Future Nostalgia",
                duration = 203
            ),
            Track(
                id = "6",
                title = "Save Your Tears",
                artist = "The Weeknd",
                album = "After Hours",
                duration = 215
            ),
            Track(
                id = "7",
                title = "Good 4 U",
                artist = "Olivia Rodrigo",
                album = "SOUR",
                duration = 178
            ),
            Track(
                id = "8",
                title = "Stay",
                artist = "The Kid LAROI, Justin Bieber",
                album = "F*CK LOVE 3+",
                duration = 138
            )
        )
    }

    /**
     * 获取歌曲详情
     */
    suspend fun getTrackDetail(id: String): Track {
        // 模拟网络延迟
        kotlinx.coroutines.delay(300)
        
        // 从假数据中查找歌曲
        return getTracks().firstOrNull { it.id == id } ?: Track(
            id = id,
            title = "Unknown Track",
            artist = "Unknown Artist",
            album = "Unknown Album",
            duration = 0
        )
    }
}
