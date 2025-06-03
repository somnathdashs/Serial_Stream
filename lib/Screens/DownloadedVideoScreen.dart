import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serial_stream/Screens/VideoPlayer/PremiumVideoScreen_offline.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:serial_stream/Screens/VideoPlayer/Player.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:serial_stream/Backend.dart';

class DownloadedVideoScreen extends StatefulWidget {
  const DownloadedVideoScreen({Key? key}) : super(key: key);

  @override
  State<DownloadedVideoScreen> createState() => _DownloadedVideoScreenState();
}

class _DownloadedVideoScreenState extends State<DownloadedVideoScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  bool _isGridView = true;
  bool _isSelectionMode = false;
  Set<String> _selectedVideos = {};
  final Map<String, List<Map<String, dynamic>>> _groupedVideos = {};
  final Map<String, Widget> _thumbnailCache = {}; // Cache for thumbnails

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear the thumbnail cache when refreshing
      _thumbnailCache.clear();
      
      // Get app directory where videos are stored
      final appDir = await getApplicationDocumentsDirectory();
      final appFiles = Directory('${appDir.path}');
      
      List<Directory> directoriesToCheck = [appFiles];
      
      try {
        // Also check external storage directory if available
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          directoriesToCheck.add(externalDir);
        }
      } catch (e) {
        print('External storage not available: $e');
      }
      
      _videos = [];
      _groupedVideos.clear();
      
      for (var directory in directoriesToCheck) {
        if (!await directory.exists()) continue;
        
        final files = await directory.list(recursive: true).toList();
        final videoFiles = files.where((file) => 
          file.path.endsWith('.mp4') || 
          file.path.endsWith('.mkv') || 
          file.path.endsWith('.avi') ||
          file.path.endsWith('.m4v') ||
          file.path.endsWith('.mov')
        ).toList();
        
        for (var file in videoFiles) {
          final fileStats = await File(file.path).stat();
          final fileName = file.path.split('/').last.split('\\').last; // Handle both path separators
          final fileNameWithoutExt = fileName.split('.').first;
          
          // Skip files smaller than 1MB (likely not actual videos)
          if (fileStats.size < 1024 * 1024) continue;
          
          // Initialize VideoPlayerController to get video duration
          VideoPlayerController? videoPlayerController;
          Duration duration = Duration.zero;
          
          try {
            videoPlayerController = VideoPlayerController.file(File(file.path));
            await videoPlayerController.initialize();
            duration = videoPlayerController.value.duration;
          } catch (e) {
            print('Error initializing video player: $e');
          } finally {
            if (videoPlayerController != null) {
              await videoPlayerController.dispose();
            }
          }
          
          // Skip if not a valid video file
          if (duration == Duration.zero) continue;

          final videoInfo = {
            'path': file.path,
            'name': fileNameWithoutExt,
            'size': _formatFileSize(fileStats.size),
            'date': fileStats.modified,
            'dateFormatted': DateFormat('dd MMM yyyy').format(fileStats.modified),
            'duration': _formatDuration(duration),
          };

          _videos.add(videoInfo);

          // Group videos by date
          final dateKey = DateFormat('yyyy-MM-dd').format(fileStats.modified);
          if (!_groupedVideos.containsKey(dateKey)) {
            _groupedVideos[dateKey] = [];
          }
          _groupedVideos[dateKey]!.add(videoInfo);
        }
      }

      // Sort videos by date (newest first)
      _videos.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      // Sort grouped video dates
      _groupedVideos.forEach((key, videos) {
        videos.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading videos: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _enterSelectionMode(String videoPath) {
    setState(() {
      _isSelectionMode = true;
      _selectedVideos.add(videoPath);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedVideos.clear();
    });
  }

  void _toggleVideoSelection(String videoPath) {
    setState(() {
      if (_selectedVideos.contains(videoPath)) {
        _selectedVideos.remove(videoPath);
        if (_selectedVideos.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedVideos.add(videoPath);
      }
    });
  }

  void _selectAllVideos() {
    setState(() {
      _selectedVideos.clear();
      for (var video in _videos) {
        _selectedVideos.add(video['path']);
      }
    });
  }

  Future<void> _deleteSelectedVideos() async {
    if (_selectedVideos.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Videos'),
        content: Text('Are you sure you want to delete ${_selectedVideos.length} selected video(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (String filePath in _selectedVideos) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            // Clear any cached thumbnails for this video
            _thumbnailCache.removeWhere((key, value) => key.startsWith('$filePath-'));
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedVideos.length} video(s) deleted successfully')),
        );
        
        _exitSelectionMode();
        _loadVideos(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting videos: $e')),
        );
      }
    }
  }

  String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return duration.inHours > 0 
        ? '$hours:$minutes:$seconds' 
        : '$minutes:$seconds';
  }

  Future<void> _deleteVideo(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        
        // Clear any cached thumbnails for this video
        _thumbnailCache.removeWhere((key, value) => key.startsWith('$filePath-'));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video deleted successfully')),
        );
        _loadVideos(); // Refresh the list
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting video: $e')),
      );
    }
  }

  Future<void> _showDeleteConfirmationDialog(Map<String, dynamic> video) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Video'),
        content: Text('Are you sure you want to delete "${video['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteVideo(video['path']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _playVideo(Map<String, dynamic> video) {
    if (_isSelectionMode) {
      _toggleVideoSelection(video['path']);
    } else {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => PremiumVideoScreen_Offline(
            videoFilePath: video['path'],
            epishodeName: video['name'],
          ),
        ),
      );
    }
  }

  Widget _buildVideoThumbnail(String videoPath, String videoName) {
    // Check if thumbnail is already in cache
    final cacheKey = '$videoPath-$videoName';
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey]!;
    }
    
    return FutureBuilder<Widget>(
      future: _generateThumbnail(videoPath, videoName: videoName).then((thumbnail) {
        // Store in cache for future use
        _thumbnailCache[cacheKey] = thumbnail;
        return thumbnail;
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && 
            snapshot.hasData) {
          return snapshot.data!;
        } else {
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }

  Future<Widget> _generateThumbnail(String videoPath, {String? videoName}) async {
    try {
      final fileName = videoPath.split('/').last.split('\\').last;
      final fileNameWithoutExt = fileName.split('.').first;
      final name = videoName ?? fileNameWithoutExt;
      
      // First try to get image from web scraping
      try {
        final imageUrl = await Backend.scrapeHDImage(name, '');
        
        if (imageUrl.isNotEmpty && !imageUrl.contains("No-Image-Found")) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildDefaultThumbnail(),
                ),
              ),
              Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white.withOpacity(0.7),
                  size: 50,
                ),
              ),
            ],
          );
        }
      } catch (e) {
        print('Error fetching image: $e');
      }
      
      // If scraping fails, try to generate from video
      try {
        VideoPlayerController controller = VideoPlayerController.file(File(videoPath));
        await controller.initialize();
        
        // If video successfully initialized, try to extract a frame
        if (controller.value.isInitialized) {
          // Set position to 20% of the video to get a meaningful frame
          await controller.seekTo(Duration(milliseconds: (controller.value.duration.inMilliseconds * 0.2).round()));
          
          // Allow a small delay for the frame to load
          await Future.delayed(Duration(milliseconds: 100));
          
          // Create the thumbnail widget with video preview overlay
          final result = Stack(
            fit: StackFit.expand,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white.withOpacity(0.7),
                  size: 50,
                ),
              ),
            ],
          );
          
          // Don't forget to dispose the controller
          await controller.dispose();
          
          return result;
        }
        
        await controller.dispose();
      } catch (e) {
        print('Error generating video thumbnail: $e');
      }
      
      // If all else fails, return default thumbnail
      return _buildDefaultThumbnail();
    } catch (e) {
      return _buildDefaultThumbnail();
    }
  }
  
  Widget _buildDefaultThumbnail() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'asserts/logo.png',
            fit: BoxFit.contain,
          ),
          Center(
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white.withOpacity(0.7),
              size: 50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> video) {
    final isSelected = _selectedVideos.contains(video['path']);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
          ? BorderSide(color: Theme.of(context).primaryColor, width: 3)
          : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        focusColor: Colors.blue.shade400,
        onTap: () => _playVideo(video),
        onLongPress: () {
          if (!_isSelectionMode) {
            _enterSelectionMode(video['path']);
          } else {
            _toggleVideoSelection(video['path']);
          }
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildVideoThumbnail(video['path'], video['name']),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            video['duration'],
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          Spacer(),
                          Text(
                            video['size'],
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          video['dateFormatted'],
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                      // if (!_isSelectionMode)
                      //   IconButton(
                      //     icon: Icon(Icons.delete, color: Colors.red),
                      //     onPressed: () => _showDeleteConfirmationDialog(video),
                      //     iconSize: 20,
                      //     padding: EdgeInsets.zero,
                      //     constraints: BoxConstraints(),
                      //   ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isSelected ? Icons.check : null,
                    color: Colors.white,
                    size: 20,
                  ),
                  width: 24,
                  height: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> video) {
    final isSelected = _selectedVideos.contains(video['path']);
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
          ? BorderSide(color: Theme.of(context).primaryColor, width: 3)
          : BorderSide.none,
      ),
      child: InkWell(
        focusColor: Colors.blue.shade400,
        onTap: () => _playVideo(video),
        onLongPress: () {
          if (!_isSelectionMode) {
            _enterSelectionMode(video['path']);
          } else {
            _toggleVideoSelection(video['path']);
          }
        },
        child: Row(
          children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isSelected ? Icons.check : null,
                    color: Colors.white,
                    size: 20,
                  ),
                  width: 24,
                  height: 24,
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width: 120,
                height: 90,
                child: _buildVideoThumbnail(video['path'], video['name']),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          video['duration'],
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          video['dateFormatted'],
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      video['size'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            // if (!_isSelectionMode)
            //   InkWell(
            //     focusColor: Colors.yellow.shade400,
            //     child: Padding(
            //       padding: const EdgeInsets.all(12.0),
            //       child: Icon(Icons.delete, color: Colors.red),
            //     ),
            //     onTap: () => _showDeleteConfirmationDialog(video),
            //   ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedVideos() {
    // Convert the map to a list of entries and sort by date (newest first)
    final sortedGroups = _groupedVideos.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return ListView.builder(
      itemCount: sortedGroups.length,
      itemBuilder: (context, groupIndex) {
        final dateKey = sortedGroups[groupIndex].key;
        final videos = sortedGroups[groupIndex].value;
        
        // Format the date for display
        final DateTime date = DateTime.parse(dateKey);
        final String displayDate = DateFormat('EEEE, MMMM d, yyyy').format(date);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                displayDate,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            if (_isGridView)
              GridView.builder(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: videos.length,
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (context, index) => _buildGridItem(videos[index]),
              )
            else
              ListView.builder(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: videos.length,
                itemBuilder: (context, index) => _buildListItem(videos[index]),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          _exitSelectionMode();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSelectionMode 
            ? Text('${_selectedVideos.length} selected')
            : Text('Downloaded Videos'),
          leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
          actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.select_all),
                  onPressed: _selectAllVideos,
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: _selectedVideos.isNotEmpty ? _deleteSelectedVideos : null,
                  tooltip: 'Delete Selected',
                ),
              ]
            : [
                IconButton(
                  icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadVideos,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: Icon(Icons.delete_forever_rounded),
                  onPressed: (){
                    setState(() {
                      _isSelectionMode = true;
                    });
                  },
                  tooltip: 'Select',
                ),
              ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading your videos...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              )
            : _videos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No videos downloaded yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Downloaded videos will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadVideos,
                          icon: Icon(Icons.refresh),
                          label: Text('Refresh'),
                        ),
                      ],
                    ),
                  )
                : AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: _buildGroupedVideos(),
                  ),
      ),
    );
  }
}