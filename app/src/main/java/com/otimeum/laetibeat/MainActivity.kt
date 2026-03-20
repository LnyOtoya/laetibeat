package com.otimeum.laetibeat

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import com.otimeum.laetibeat.model.Track
import com.otimeum.laetibeat.ui.components.MiniPlayer
import com.otimeum.laetibeat.ui.navigation.AppNavigation
import com.otimeum.laetibeat.ui.navigation.AppRoutes
import com.otimeum.laetibeat.ui.screens.player.NowPlayingScreen
import com.otimeum.laetibeat.ui.theme.LaetibeatTheme
import com.otimeum.laetibeat.viewmodel.PlayerViewModel
import kotlinx.coroutines.launch

import android.view.WindowManager

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 设置状态栏透明
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        
        setContent {
            LaetibeatTheme {
                // A surface container using the 'background' color from the theme
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MusicPlayerApp()
                }
            }
        }
    }
}

@Composable
fun MusicPlayerApp() {
    val navController = rememberNavController()
    val viewModel: PlayerViewModel = viewModel()
    val playerState by viewModel.playerState.collectAsState()

    // 加载歌曲列表
    LaunchedEffect(Unit) {
        viewModel.loadTracks()
    }

    Box(
        modifier = Modifier.fillMaxSize()
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
        ) {
            // 导航宿主
            Box(
                modifier = Modifier.weight(1f)
            ) {
                AppNavigation(
                    navController = navController,
                    viewModel = viewModel
                )
            }

            // 迷你播放器
            MiniPlayer(
                currentTrack = playerState.currentTrack,
                status = playerState.status,
                onPlayPause = viewModel::togglePlayPause,
                onNext = viewModel::playNext,
                onNavigateToNowPlaying = {
                    navController.navigate(AppRoutes.NOW_PLAYING)
                }
            )

            // 底部导航栏
            NavigationBar(
                modifier = Modifier.fillMaxWidth()
            ) {
                NavigationBarItem(
                        selected = navController.currentDestination?.route == AppRoutes.HOME,
                        onClick = {
                            navController.navigate(AppRoutes.HOME) {
                                popUpTo(navController.graph.startDestinationId) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(Icons.Filled.Home, contentDescription = "Home") },
                        label = { Text("Home") }
                    )
                    NavigationBarItem(
                        selected = navController.currentDestination?.route == AppRoutes.SEARCH,
                        onClick = {
                            navController.navigate(AppRoutes.SEARCH) {
                                popUpTo(navController.graph.startDestinationId) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(Icons.Filled.Search, contentDescription = "Search") },
                        label = { Text("Search") }
                    )
                    NavigationBarItem(
                        selected = navController.currentDestination?.route == AppRoutes.LIBRARY,
                        onClick = {
                            navController.navigate(AppRoutes.LIBRARY) {
                                popUpTo(navController.graph.startDestinationId) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(Icons.Filled.LibraryMusic, contentDescription = "Library") },
                        label = { Text("Library") }
                    )
            }
        }
    }
}
