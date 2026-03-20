package com.otimeum.laetibeat.model

/**
 * 播放队列模型类
 * 管理当前播放列表和索引
 */
data class Queue(
    val tracks: List<Track>,
    val currentIndex: Int,
    val isShuffle: Boolean = false,
    val isRepeat: Boolean = false
) {
    /**
     * 获取当前播放的歌曲
     */
    val currentTrack: Track?
        get() = if (tracks.isNotEmpty() && currentIndex in tracks.indices) tracks[currentIndex] else null

    /**
     * 获取下一首歌曲的索引
     */
    fun getNextIndex(): Int {
        if (tracks.isEmpty()) return -1
        
        return if (isShuffle) {
            // 随机模式下，随机选择一个索引
            (0 until tracks.size).filter { it != currentIndex }.randomOrNull() ?: 0
        } else {
            // 顺序模式下，循环播放
            (currentIndex + 1) % tracks.size
        }
    }

    /**
     * 获取上一首歌曲的索引
     */
    fun getPrevIndex(): Int {
        if (tracks.isEmpty()) return -1
        
        return if (isShuffle) {
            // 随机模式下，随机选择一个索引
            (0 until tracks.size).filter { it != currentIndex }.randomOrNull() ?: 0
        } else {
            // 顺序模式下，循环播放
            if (currentIndex == 0) tracks.size - 1 else currentIndex - 1
        }
    }
}
