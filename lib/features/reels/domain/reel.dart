import '../../feed/domain/feed_post.dart';

class Reel {
  const Reel({
    required this.id,
    required this.caption,
    required this.category,
    required this.author,
    required this.videoUrl,
    required this.createdAt,
    required this.sizeBytes,
    this.durationSeconds,
  });

  final String id;
  final String caption;
  final String category;
  final PostAuthor author;
  final String? videoUrl;
  final DateTime createdAt;
  final int sizeBytes;
  final int? durationSeconds;

  factory Reel.fromJson(Map<String, dynamic> json) => Reel(
        id: json['id'] as String,
        caption: (json['caption'] as String?) ?? '',
        category: json['category'] as String,
        author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
        videoUrl: json['videoUrl'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      );
}

class ReelsFeed {
  const ReelsFeed({required this.reels, required this.uploadEnabled});

  final List<Reel> reels;
  final bool uploadEnabled;
}
