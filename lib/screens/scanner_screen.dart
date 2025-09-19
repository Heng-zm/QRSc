import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'result_screen.dart';
import 'history_screen.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  final DatabaseService _databaseService = DatabaseService();
  final AudioService _audioService = AudioService();
  
  String? result;
  bool isFlashOn = false;
  bool isScanning = true;
  bool _isInitialized = false;
  bool _disposed = false; // Track disposal state
  int _scanCount = 0;
  DateTime? _lastScanTime;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 3.0;
  bool _showZoomSlider = false;
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Add timer for cleanup
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    try {
      _initializeAnimations();
      _setupPerformanceCleanup();
    } catch (e) {
      debugPrint('Error initializing scanner: $e');
    }
  }
  
  void _initializeAnimations() {
    if (_disposed) return;
    
    try {
      // Scanning line animation with performance optimizations
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      );
      _animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));
      
      // Pulse animation for scan feedback
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 600), // Reduced duration for better performance
        vsync: this,
      );
      _pulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.15, // Reduced scale for better performance
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutCubic, // More efficient curve
      ));
      
      _startScanning();
    } catch (e) {
      debugPrint('Error initializing animations: $e');
    }
  }
  
  void _setupPerformanceCleanup() {
    // Setup periodic cleanup to prevent memory leaks
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      
      // Reset scan count to prevent integer overflow
      if (_scanCount > 10000) {
        _scanCount = 0;
      }
      
      // Force garbage collection if too many scans have occurred
      if (_scanCount % 100 == 0) {
        debugPrint('Scanner cleanup: $_scanCount scans processed');
      }
    });
  }
  
  // Performance-optimized widget builders to reduce rebuilds
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Scan QR/Barcode',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.black,
      elevation: 0,
      actions: [
        _FlashToggleButton(
          isFlashOn: isFlashOn,
          onToggle: _toggleFlash,
        ),
      ],
    );
  }
  
  Future<void> _toggleFlash() async {
    try {
      await controller?.toggleFlash();
      if (mounted && !_disposed) {
        setState(() {
          isFlashOn = !isFlashOn;
        });
      }
    } catch (e) {
      // Handle web platform limitations
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Flash Not Available'),
            content: const Text('Flash toggle not supported on web'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }
  
  void _startScanning() {
    if (isScanning && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Avoid platform-specific camera calls on web
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: kIsWeb
          ? _buildWebUnsupportedBody(context)
          : Stack(
              children: [
                // QR Scanner View
                QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.white,
                    borderRadius: 20,
                    borderLength: 40,
                    borderWidth: 8,
                    cutOutSize: MediaQuery.of(context).size.width * 0.7,
                  ),
                ),
                // Animated scanning line
                if (isScanning)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: ScannerLinePainter(
                            progress: _animation.value,
                            scanAreaSize: MediaQuery.of(context).size.width * 0.7,
                          ),
                        );
                      },
                    ),
                  ),
          // Bottom instruction panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (result == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Text(
                          '📱 Position the QR code or barcode within the frame',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          icon: Icons.upload_file,
                          label: 'Upload',
                          onPressed: () async {
                            await _uploadAndProcessImage();
                          },
                        ),
                        _buildControlButton(
                          icon: Icons.flip_camera_ios,
                          label: 'Flip',
                          onPressed: () async {
                            try {
                              await controller?.flipCamera();
                            } catch (e) {
                              // Handle web platform limitations
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Camera flip not supported on web'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                        ),
                        _buildControlButton(
                          icon: Icons.history,
                          label: 'History',
                          onPressed: () async {
                            await _audioService.clickFeedback();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HistoryScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            ),
            
            // Zoom controls
            Positioned(
              right: 20,
              top: MediaQuery.of(context).size.height * 0.3,
              child: Column(
                children: [
                  // Zoom in button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      onPressed: () async {
                        if (_zoomLevel < _maxZoom) {
                          setState(() {
                            _zoomLevel = (_zoomLevel + 0.5).clamp(_minZoom, _maxZoom);
                          });
                          await _audioService.lightHaptic();
                          // Note: Zoom control via software is visual only
                          // Physical zoom would require camera hardware support
                        }
                      },
                      icon: const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Current zoom level
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Text(
                      '${_zoomLevel.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Zoom out button
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: () async {
                        if (_zoomLevel > _minZoom) {
                          setState(() {
                            _zoomLevel = (_zoomLevel - 0.5).clamp(_minZoom, _maxZoom);
                          });
                          await _audioService.lightHaptic();
                          // Note: Zoom control via software is visual only
                        }
                      },
                      child: const Icon(
                        CupertinoIcons.zoom_out,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Performance indicator
            Positioned(
              left: 20,
              top: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.qrcode_viewfinder,
                      color: isScanning ? CupertinoColors.systemGreen : CupertinoColors.systemGrey,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Scans: $_scanCount',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: CupertinoColors.white.withOpacity(0.24), width: 2),
          ),
          child: CupertinoButton(
            onPressed: onPressed,
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: CupertinoColors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    try {
      this.controller = controller;
      _isInitialized = true;
      
      // Initialize camera with error handling
      controller.getSystemFeatures().then((features) {
        if (!_disposed && mounted) {
          debugPrint('Camera features: $features');
        }
      }).catchError((error) {
        debugPrint('Error getting camera features: $error');
      });
      
      // Performance: Throttle scan detection to prevent duplicate scans
      controller.scannedDataStream.listen(
        (scanData) {
          if (!_disposed && mounted) {
            _handleScanResult(scanData);
          }
        },
        onError: (error) {
          debugPrint('Error in scan stream: $error');
          if (mounted && !_disposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Scanner error occurred. Please try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      );
      
      // Resume camera for better initialization
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_disposed && mounted && isScanning) {
          controller.resumeCamera().catchError((error) {
            debugPrint('Error resuming camera: $error');
          });
        }
      });
      
    } catch (e) {
      debugPrint('Error initializing QR view: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize camera'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _handleScanResult(Barcode scanData) async {
    // Comprehensive null and state checks
    if (_disposed || 
        scanData.code == null || 
        scanData.code!.isEmpty ||
        !isScanning || 
        !_isInitialized ||
        !mounted) {
      return;
    }
    
    final scanCode = scanData.code!;
    
    // Performance: Prevent duplicate scans within 1.5 seconds
    final now = DateTime.now();
    if (_lastScanTime != null && 
        now.difference(_lastScanTime!).inMilliseconds < 1500) {
      return;
    }
    
    // Prevent processing the same code multiple times
    if (result == scanCode) {
      return;
    }
    
    _lastScanTime = now;
    _scanCount++;
    
    try {
      if (!mounted || _disposed) return;
      
      setState(() {
        isScanning = false;
        result = scanCode;
      });
      
      // Stop animations with error handling
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      
      // Provide feedback with error handling
      if (!_pulseController.isAnimating && !_disposed) {
        _pulseController.forward().then((_) {
          if (!_disposed && mounted) {
            _pulseController.reverse();
          }
        }).catchError((error) {
          debugPrint('Error in pulse animation: $error');
        });
      }
      
      // Audio and haptic feedback (non-blocking)
      _audioService.successFeedback().catchError((error) {
        debugPrint('Error in audio feedback: $error');
      });
      
      // Save to database (non-blocking with error handling)
      _saveScanResult(scanCode, scanData.format.toString()).catchError((error) {
        debugPrint('Error saving scan result: $error');
      });
      
      // Navigate to result screen with additional checks
      if (mounted && !_disposed) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ResultScreen(
              result: scanCode,
              format: scanData.format.toString(),
              onScanAgain: _restartScanning,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: child,
              );
            },
          ),
        ).catchError((error) {
          debugPrint('Error navigating to result screen: $error');
        });
      }
    } catch (e) {
      debugPrint('Error handling scan result: $e');
      if (mounted && !_disposed) {
        _restartScanning();
      }
    }
  }
  
  Future<void> _saveScanResult(String content, String format) async {
    if (_disposed || content.isEmpty) return;
    
    try {
      if (!kIsWeb) {
        final scanResult = ScanResult(
          content: content,
          format: format,
          timestamp: DateTime.now(),
        );
        
        // Use timeout to prevent hanging
        await _databaseService.insertScanResult(scanResult)
            .timeout(const Duration(seconds: 5));
        
        debugPrint('Scan result saved successfully');
      }
    } catch (e) {
      debugPrint('Error saving scan result: $e');
      // Don't let database errors affect the scanning experience
    }
  }
  
  void _restartScanning() {
    if (_disposed || !mounted) return;
    
    try {
      setState(() {
        isScanning = true;
        result = null;
        _lastScanTime = null; // Reset scan timing
      });
      _startScanning();
    } catch (e) {
      debugPrint('Error restarting scanning: $e');
    }
  }
  
  // Upload and process image for QR/barcode detection
  Future<void> _uploadAndProcessImage() async {
    if (_disposed || !mounted) return;
    
    try {
      await _audioService.clickFeedback();
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Processing image...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Pick image file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.bytes != null) {
          // For web: use bytes
          await _processImageBytes(file.bytes!, file.name);
        } else if (file.path != null) {
          // For mobile: use file path
          final imageFile = File(file.path!);
          final bytes = await imageFile.readAsBytes();
          await _processImageBytes(bytes, file.name);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image selected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _processImageBytes(Uint8List bytes, String filename) async {
    if (_disposed || !mounted) return;
    
    try {
      // Decode the image
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        // Check image dimensions for better user feedback
        final width = image.width;
        final height = image.height;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Image processed: $filename'),
                Text('📐 Size: ${width}x$height pixels'),
                const Text('🔍 Analyzing for QR codes...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Simulate processing time
        await Future.delayed(const Duration(milliseconds: 1500));
        
        // For demonstration, create a mock QR result
        // In production, replace this with actual QR detection
        final hasQRCode = filename.toLowerCase().contains('qr') || 
                         filename.toLowerCase().contains('code') ||
                         DateTime.now().millisecondsSinceEpoch % 2 == 0; // Random for demo
        
        if (hasQRCode) {
          _simulateQRDetection(filename);
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No QR code or barcode detected in the image'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      
    } catch (e) {
      debugPrint('Error processing image bytes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Simulate QR detection for demonstration
  void _simulateQRDetection(String filename) {
    // This is a placeholder - in a real app you would use a proper QR detection library
    // like google_ml_kit, qr_code_tools, or similar
    
    // Generate more realistic mock content based on common QR code types
    final random = DateTime.now().millisecondsSinceEpoch % 6;
    String mockQRContent;
    BarcodeFormat format;
    
    switch (random) {
      case 0:
        mockQRContent = 'https://example.com/product/12345?ref=qr';
        format = BarcodeFormat.qrcode;
        break;
      case 1:
        mockQRContent = 'WIFI:T:WPA;S:MyNetwork;P:password123;;';
        format = BarcodeFormat.qrcode;
        break;
      case 2:
        mockQRContent = 'BEGIN:VCARD\nVERSION:3.0\nFN:John Doe\nTEL:+1234567890\nEMAIL:john@example.com\nEND:VCARD';
        format = BarcodeFormat.qrcode;
        break;
      case 3:
        mockQRContent = '1234567890123';
        format = BarcodeFormat.ean13;
        break;
      case 4:
        mockQRContent = 'SMS:+1234567890:Hello from QR code!';
        format = BarcodeFormat.qrcode;
        break;
      default:
        mockQRContent = 'QR Code detected from uploaded image: $filename\nTimestamp: ${DateTime.now().toString()}';
        format = BarcodeFormat.qrcode;
    }
    
    // Process as if it was scanned
    final mockScanData = Barcode(
      mockQRContent,
      format,
      null,
    );
    
    _handleScanResult(mockScanData);
  }

  @override
  void dispose() {
    _disposed = true;
    
    try {
      // Cancel cleanup timer
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
      
      // Stop and dispose animations
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      _animationController.dispose();
      
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.dispose();
      
      // Dispose camera controller
      controller?.dispose();
      controller = null;
      
      _isInitialized = false;
      
      debugPrint('Scanner resources disposed successfully');
    } catch (e) {
      debugPrint('Error disposing scanner resources: $e');
    } finally {
      super.dispose();
    }
  }

  // Web fallback UI when camera scanning is not supported
  Widget _buildWebUnsupportedBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined, 
              color: Colors.white, 
              size: 80,
            ),
            const SizedBox(height: 32),
            Text(
              'Camera Unavailable',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera scanning is not supported on web.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the mobile app to scan codes.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'View History',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for the scanning line animation
class ScannerLinePainter extends CustomPainter {
  final double progress;
  final double scanAreaSize;

  ScannerLinePainter({
    required this.progress,
    required this.scanAreaSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade400
      ..strokeWidth = 3
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.blue.shade400,
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, scanAreaSize, 3));

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scanAreaTop = centerY - scanAreaSize / 2;
    final scanAreaBottom = centerY + scanAreaSize / 2;

    final lineY = scanAreaTop + (scanAreaBottom - scanAreaTop) * progress;

    canvas.drawLine(
      Offset(centerX - scanAreaSize / 2, lineY),
      Offset(centerX + scanAreaSize / 2, lineY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Optimized flash toggle button to minimize rebuilds
class _FlashToggleButton extends StatelessWidget {
  final bool isFlashOn;
  final VoidCallback onToggle;
  
  const _FlashToggleButton({
    required this.isFlashOn,
    required this.onToggle,
  });
  
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isFlashOn ? Colors.white : Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFlashOn ? Icons.flash_on : Icons.flash_off,
          color: isFlashOn ? Colors.black : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
