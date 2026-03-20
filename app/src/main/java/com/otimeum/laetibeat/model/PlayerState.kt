package com.otimeum.laetibeat.model

/**
 * 播放器状态枚举
 */
enum class PlayerStatus {
    PLAYING,
    PAUSED,
    IDLE
}

/**
 * 播放器状态模型类
 * 管理播放器的当前状态
 */
data class PlayerState(
    val status: PlayerStatus,
    val currentTrack: Track?,
    val progress: Int, // 当前播放进度，单位：秒
    val queue: Queue
)
