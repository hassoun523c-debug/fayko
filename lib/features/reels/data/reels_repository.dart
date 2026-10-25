import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../domain/reel.dart';

abstract interface class ReelsRepository {
  Future<ReelsFeed> loadReels({
    required String accessToken,
    String? category,
  });

  Future<Reel> uploadReel({
    required String accessToken,
    required XFile video,
    required String category,
    required String caption,
  });

  Future<void> deleteReel({
    required String accessToken,
    required String reelId,
  });
}

class RemoteReelsRepository implements ReelsRepository {
  const RemoteReelsRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const maxReelBytes = 150 * 1024 * 1024;
  static const maxReelDurationSeconds = 180;

  @override
  Future<ReelsFeed> loadReels({
    required String accessToken,
    String? category,
  }) async {
    final payload = await _apiClient.get(
      '/reels',
      token: accessToken,
      queryParameters: {
        'limit': '20',
        if (category != null) 'category': category,
      },
    );
    final rawReels = payload['reels'];
    if (rawReels is! List || payload['uploadEnabled'] is! bool) {
      throw const FormatException('Invalid reels response.');
    }
    return ReelsFeed(
      reels: rawReels
          .whereType<Map<String, dynamic>>()
          .map(Reel.fromJson)
          .toList(growable: false),
      uploadEnabled: payload['uploadEnabled'] as bool,
    );
  }

  @override
  Future<Reel> uploadReel({
    required String accessToken,
    required XFile video,
    required String category,
    required String caption,
  }) async {
    final filename = video.name.toLowerCase();
    if (!filename.endsWith('.mp4')) {
      throw const FormatException('اختار فيديو بصيغة MP4.');
    }

    final sizeBytes = await video.length();
    if (sizeBytes < 1 || sizeBytes > maxReelBytes) {
      throw const FormatException('حجم الفيديو لازم يكون أقل من 150 ميگابايت.');
    }

    final uploadData = await _apiClient.post(
      '/reels/upload-url',
      token: accessToken,
      body: {
        'category': category,
        'contentType': 'video/mp4',
        'fileSizeBytes': sizeBytes,
      },
    );
    final uploadUrl = uploadData['uploadUrl'];
    final objectKey = uploadData['objectKey'];
    if (uploadUrl is! String || objectKey is! String) {
      throw const FormatException('استجابة رابط رفع الفيديو غير صالحة.');
    }

    final client = http.Client();
    try {
      final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl))
        ..headers['content-type'] = 'video/mp4'
        ..contentLength = sizeBytes;
      final responseFuture = client.send(request);
      await request.sink.addStream(video.openRead());
      await request.sink.close();
      final response = await responseFuture.timeout(const Duration(minutes: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          code: 'media_upload_failed',
          message: 'تعذر رفع الفيديو إلى مخزن الوسائط. حاول مجدداً.',
        );
      }
    } on TimeoutException {
      rethrow;
    } finally {
      client.close();
    }

    final result = await _apiClient.post(
      '/reels',
      token: accessToken,
      body: {
        'objectKey': objectKey,
        'caption': caption.trim(),
        'category': category,
        'contentType': 'video/mp4',
        'fileSizeBytes': sizeBytes,
      },
    );
    final rawReel = result['reel'];
    if (rawReel is! Map<String, dynamic>) {
      throw const FormatException('Invalid uploaded reel response.');
    }
    return Reel.fromJson(rawReel);
  }

  @override
  Future<void> deleteReel({
    required String accessToken,
    required String reelId,
  }) async {
    await _apiClient.delete('/reels/$reelId', token: accessToken);
  }
}
