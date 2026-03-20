package com.otimeum.laetibeat.model

/**
 * 歌曲模型类
 * 包含歌曲的基本信息
 */
data class Track(
    val id: String,
    val title: String,
    val artist: String,
    val album: String,
    val duration: Int, // 时长，单位：秒
    val coverUrl: String? = null // 封面 URL，可选
)
