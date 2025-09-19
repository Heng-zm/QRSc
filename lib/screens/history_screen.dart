import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final AudioService _audioService = AudioService();
  final TextEditingController _searchController = TextEditingController();
  
  List<ScanResult> _scanResults = [];
  List<ScanResult> _filteredResults = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, favorites, today, week
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
    _loadScanResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadScanResults() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final results = await _databaseService.getAllScanResults(limit: 500)
          .timeout(const Duration(seconds: 10));
      
      if (!mounted) return;
      
      setState(() {
        _scanResults = results ?? [];
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading scan results: $e');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load scan history: ${e.toString()}');
    }
  }

  void _applyFilters() {
    List<ScanResult> filtered = List.from(_scanResults);
    final now = DateTime.now();

    // Apply filter
    switch (_selectedFilter) {
      case 'favorites':
        filtered = filtered.where((result) => result.isFavorite).toList();
        break;
      case 'today':
        filtered = filtered.where((result) {
          return result.timestamp.day == now.day &&
                 result.timestamp.month == now.month &&
                 result.timestamp.year == now.year;
        }).toList();
        break;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered.where((result) => 
            result.timestamp.isAfter(weekAgo)).toList();
        break;
    }

    // Apply search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((result) =>
          result.content.toLowerCase().contains(query) ||
          (result.title?.toLowerCase().contains(query) ?? false)).toList();
    }

    setState(() => _filteredResults = filtered);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleFavorite(ScanResult result) async {
    if (!mounted) return;
    
    try {
      await _audioService.selectionHaptic();
      
      final updatedResult = result.copyWith(isFavorite: !result.isFavorite);
      await _databaseService.updateScanResult(updatedResult)
          .timeout(const Duration(seconds: 5));
      
      if (!mounted) return;
      
      // Optimistic UI update
      setState(() {
        final index = _scanResults.indexWhere((r) => r.id == result.id);
        if (index != -1) {
          _scanResults[index] = updatedResult;
          _applyFilters();
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedResult.isFavorite 
                ? 'Added to favorites' 
                : 'Removed from favorites'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to update favorite status');
      }
    }
  }

  Future<void> _deleteResult(ScanResult result) async {
    if (!mounted || result.id == null) return;
    
    try {
      await _audioService.mediumHaptic();
      
      if (!mounted) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Scan Result'),
          content: const Text('Are you sure you want to delete this scan result?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        try {
          await _databaseService.deleteScanResult(result.id!)
              .timeout(const Duration(seconds: 5));
          
          if (!mounted) return;
          
          // Optimistic UI update
          setState(() {
            _scanResults.removeWhere((r) => r.id == result.id);
            _applyFilters();
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Scan result deleted'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error deleting scan result: $e');
          if (mounted) {
            _showErrorSnackBar('Failed to delete scan result');
            // Reload data to ensure consistency
            _loadScanResults();
          }
        }
      }
    } catch (e) {
      debugPrint('Error in delete operation: $e');
      if (mounted) {
        _showErrorSnackBar('An error occurred during deletion');
      }
    }
  }

  Future<void> _clearAllHistory() async {
    await _audioService.mediumHaptic();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text('Are you sure you want to delete all scan history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      try {
        await _databaseService.clearAllScanResults();
        _loadScanResults();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All scan history cleared'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        _showErrorSnackBar('Failed to clear scan history');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Scan History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _clearAllHistory();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('Clear All History'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CupertinoTextField(
                    controller: _searchController,
                    onChanged: (value) => _applyFilters(),
                    placeholder: 'Search scan history...',
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.search, color: CupertinoColors.systemGrey),
                    ),
                    suffix: _searchController.text.isNotEmpty
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                            child: const Icon(CupertinoIcons.clear, size: 18),
                          )
                        : null,
                    decoration: const BoxDecoration(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All', Icons.list),
                      const SizedBox(width: 8),
                      _buildFilterChip('favorites', 'Favorites', Icons.favorite),
                      const SizedBox(width: 8),
                      _buildFilterChip('today', 'Today', Icons.today),
                      const SizedBox(width: 8),
                      _buildFilterChip('week', 'This Week', Icons.date_range),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Results list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredResults.isEmpty
                    ? _buildEmptyState()
                    : AnimationLimiter(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredResults.length,
                          itemBuilder: (context, index) {
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: _buildScanResultCard(_filteredResults[index]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = value);
          _applyFilters();
          _audioService.selectionHaptic();
        }
      },
      selectedColor: Colors.blue.shade800,
      backgroundColor: Colors.white24,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No results found'
                : 'No scan history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Start scanning QR codes and barcodes to see them here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScanResultCard(ScanResult result) {
    final formattedDate = DateFormat('MMM dd, yyyy • HH:mm').format(result.timestamp);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _audioService.selectionHaptic();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                result: result.content,
                format: result.format,
                onScanAgain: () {},
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Format indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatType(result.format),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Favorite button
                  IconButton(
                    icon: Icon(
                      result.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: result.isFavorite ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => _toggleFavorite(result),
                    visualDensity: VisualDensity.compact,
                  ),
                  // More options
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) async {
                      switch (value) {
                        case 'copy':
                          await Clipboard.setData(ClipboardData(text: result.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                          break;
                        case 'share':
                          await Share.share(result.content);
                          break;
                        case 'open':
                          if (_isUrl(result.content)) {
                            final uri = Uri.parse(result.content);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          }
                          break;
                        case 'delete':
                          _deleteResult(result);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: ListTile(
                          leading: Icon(Icons.copy),
                          title: Text('Copy'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.share),
                          title: Text('Share'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (_isUrl(result.content))
                        const PopupMenuItem(
                          value: 'open',
                          child: ListTile(
                            leading: Icon(Icons.open_in_new),
                            title: Text('Open Link'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Content preview
              Text(
                result.content,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // Timestamp
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatType(String format) {
    if (format.contains('QR_CODE')) return 'QR Code';
    if (format.contains('CODE_128')) return 'Code 128';
    if (format.contains('CODE_39')) return 'Code 39';
    if (format.contains('EAN_13')) return 'EAN-13';
    if (format.contains('EAN_8')) return 'EAN-8';
    if (format.contains('UPC_A')) return 'UPC-A';
    if (format.contains('UPC_E')) return 'UPC-E';
    return format.replaceAll('_', ' ');
  }

  bool _isUrl(String text) {
    return text.startsWith('http://') || 
           text.startsWith('https://') ||
           text.startsWith('www.');
  }
}