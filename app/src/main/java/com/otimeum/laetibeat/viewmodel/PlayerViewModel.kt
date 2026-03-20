package com.otimeum.laetibeat.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.otimeum.laetibeat.model.Queue
import com.otimeum.laetibeat.model.PlayerState
import com.otimeum.laetibeat.model.PlayerStatus
import com.otimeum.laetibeat.model.Track
import com.otimeum.laetibeat.repository.MusicRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * 播放器视图模型
 * 管理播放器状态和操作
 */
class PlayerViewModel : ViewModel() {
    private val musicRepository = MusicRepository()

    // 内部状态流
    private val _playerState = MutableStateFlow(
        PlayerState(
            status = PlayerStatus.IDLE,
            currentTrack = null,
            progress = 0,
            queue = Queue(
                tracks = emptyList(),
                currentIndex = -1
            )
        )
    )

    // 公开的状态流
    val playerState: StateFlow<PlayerState> = _playerState.asStateFlow()

    // 加载歌曲列表
    fun loadTracks() {
        viewModelScope.launch {
            val tracks = musicRepository.getTracks()
            _playerState.update {
                it.copy(
                    queue = Queue(
                        tracks = tracks,
                        currentIndex = if (tracks.isNotEmpty()) 0 else -1
                    ),
                    currentTrack = if (tracks.isNotEmpty()) tracks[0] else null
                )
            }
        }
    }

    // 播放/暂停切换
    fun togglePlayPause() {
        _playerState.update {
            val newStatus = when (it.status) {
                PlayerStatus.PLAYING -> PlayerStatus.PAUSED
                PlayerStatus.PAUSED, PlayerStatus.IDLE -> PlayerStatus.PLAYING
            }
            it.copy(status = newStatus)
        }
    }

    // 播放下一首
    fun playNext() {
        _playerState.update {
            val nextIndex = it.queue.getNextIndex()
            val nextTrack = if (nextIndex in it.queue.tracks.indices) {
                it.queue.tracks[nextIndex]
            } else {
                null
            }
            it.copy(
                queue = it.queue.copy(currentIndex = nextIndex),
                currentTrack = nextTrack,
                progress = 0,
                status = PlayerStatus.PLAYING
            )
        }
    }

    // 播放上一首
    fun playPrevious() {
        _playerState.update {
            val prevIndex = it.queue.getPrevIndex()
            val prevTrack = if (prevIndex in it.queue.tracks.indices) {
                it.queue.tracks[prevIndex]
            } else {
                null
            }
            it.copy(
                queue = it.queue.copy(currentIndex = prevIndex),
                currentTrack = prevTrack,
                progress = 0,
                status = PlayerStatus.PLAYING
            )
        }
    }

    // 播放指定歌曲
    fun playTrack(track: Track) {
        _playerState.update {
            val index = it.queue.tracks.indexOfFirst { t -> t.id == track.id }
            it.copy(
                queue = it.queue.copy(currentIndex = index),
                currentTrack = track,
                progress = 0,
                status = PlayerStatus.PLAYING
            )
        }
    }

    // 更新播放进度
    fun updateProgress(progress: Int) {
        _playerState.update {
            it.copy(progress = progress)
        }
    }

    // 切换随机播放
    fun toggleShuffle() {
        _playerState.update {
            it.copy(
                queue = it.queue.copy(isShuffle = !it.queue.isShuffle)
            )
        }
    }

    // 切换循环播放
    fun toggleRepeat() {
        _playerState.update {
            it.copy(
                queue = it.queue.copy(isRepeat = !it.queue.isRepeat)
            )
        }
    }
}
