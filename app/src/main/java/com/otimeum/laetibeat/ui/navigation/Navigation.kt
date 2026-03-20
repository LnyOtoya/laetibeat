package com.otimeum.laetibeat.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.otimeum.laetibeat.model.Track
import com.otimeum.laetibeat.ui.screens.home.HomeScreen
import com.otimeum.laetibeat.ui.screens.library.LibraryScreen
import com.otimeum.laetibeat.ui.screens.player.NowPlayingScreen
import com.otimeum.laetibeat.ui.screens.search.SearchScreen
import com.otimeum.laetibeat.viewmodel.PlayerViewModel

/**
 * 导航路由定义
 */
object AppRoutes {
    const val HOME = "home"
    const val SEARCH = "search"
    const val LIBRARY = "library"
    const val NOW_PLAYING = "now_playing"
}

/**
 * 应用导航宿主
 */
@Composable
fun AppNavigation(
    navController: NavHostController,
    viewModel: PlayerViewModel
) {
    NavHost(
        navController = navController,
        startDestination = AppRoutes.HOME
    ) {
        composable(AppRoutes.HOME) {
            HomeScreen(
                onPlayTrack = { track: Track -> viewModel.playTrack(track) },
                onNavigateToNowPlaying = {
                    navController.navigate(AppRoutes.NOW_PLAYING)
                }
            )
        }
        composable(AppRoutes.SEARCH) {
            SearchScreen(
                onPlayTrack = { track: Track -> viewModel.playTrack(track) },
                onNavigateToNowPlaying = {
                    navController.navigate(AppRoutes.NOW_PLAYING)
                }
            )
        }
        composable(AppRoutes.LIBRARY) {
            LibraryScreen(
                onPlayTrack = { track: Track -> viewModel.playTrack(track) },
                onNavigateToNowPlaying = {
                    navController.navigate(AppRoutes.NOW_PLAYING)
                }
            )
        }
        composable(AppRoutes.NOW_PLAYING) {
            NowPlayingScreen(
                onBack = {
                    navController.popBackStack()
                },
                currentTrack = viewModel.playerState.value.currentTrack,
                status = viewModel.playerState.value.status,
                progress = viewModel.playerState.value.progress,
                onPlayPause = viewModel::togglePlayPause,
                onPrevious = viewModel::playPrevious,
                onNext = viewModel::playNext,
                onProgressChange = { value ->
                    val totalDuration = viewModel.playerState.value.currentTrack?.duration ?: 0
                    val newProgress = (value * totalDuration).toInt()
                    viewModel.updateProgress(newProgress)
                },
                onToggleShuffle = viewModel::toggleShuffle,
                onToggleRepeat = viewModel::toggleRepeat
            )
        }
    }
}
