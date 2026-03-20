package com.otimeum.laetibeat.network

import com.otimeum.laetibeat.model.Track

/**
 * API 服务接口
 * 定义与后端交互的方法
 * 目前仅定义接口，不实现
 */
interface ApiService {
    /**
     * 获取歌曲列表
     */
    suspend fun getTracks(): List<Track>

    /**
     * 获取歌曲详情
     */
    suspend fun getTrackDetail(id: String): Track

    /**
     * 播放歌曲
     */
    suspend fun playTrack(id: String)

    /**
     * 暂停播放
     */
    suspend fun pauseTrack()

    /**
     * 继续播放
     */
    suspend fun resumeTrack()

    /**
     * 获取播放状态
     */
    suspend fun getPlaybackState()
}
