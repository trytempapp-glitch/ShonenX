import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shonenx/core/models/anime/anime_model.dep.dart';
import 'package:shonenx/features/watchlist/view_model/watchlist_notifier.dart';
import 'package:shonenx/shared/ui/glass/shonenx_glass_shard.dart';

class ImportReviewDialog extends ConsumerStatefulWidget {
  const ImportReviewDialog({super.key});

  @override
  ConsumerState<ImportReviewDialog> createState() => _ImportReviewDialogState();
}

class _ImportReviewDialogState extends ConsumerState<ImportReviewDialog> {
  final TextEditingController _controller = TextEditingController();
  late Future<ImportWatchlistPreview> _previewFuture;
  String _status = 'plan_to_watch';
  bool _isSaving = false;
  bool _isAnalyzing = false;
  String? _error;
  List<ImportWatchlistItem> _items = [];

  @override
  void initState() {
    super.initState();
    _previewFuture = Future.value(ImportWatchlistPreview(items: [], totalCount: 0));
  }

  Future<void> _toggleItem(ImportWatchlistItem item) async {
    setState(() {
      item.selected = !item.selected;
    });
  }

  Future<void> _analyzeList() async {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) {
      setState(() {
        _error = 'Please paste a list of anime titles first.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _items = [];
    });

    try {
      final preview = await ref
          .read(watchlistProvider.notifier)
          .analyzeAnimeList(rawText);
      setState(() {
        _previewFuture = Future.value(preview);
        _items = preview.items;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to analyze your list. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _saveSelected() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(watchlistProvider.notifier)
          .saveSelectedItems(_items, _status);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save selected anime. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildMatchCard(BuildContext context, ImportWatchlistItem item) {
    final theme = Theme.of(context);
    final title = item.matchedAnime?.name ?? item.originalTitle;
    final imageUrl = item.matchedAnime?.poster ?? '';
    final isLowConfidence = item.similarity < 0.7;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () => _toggleItem(item),
        child: Stack(
          children: [
            ShonenXGlassShard.network(
              width: double.infinity,
              height: 160,
              imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/400x225?text=No+Image',
              isDark: theme.brightness == Brightness.dark,
              blurSigma: 6,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.originalTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                item.matchedAnime != null ? Icons.check_circle : Icons.error_outline,
                                color: item.matchedAnime != null ? Colors.greenAccent : Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.matchedAnime != null
                                    ? '${(item.similarity * 100).toStringAsFixed(0)}% match'
                                    : 'No match found',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          if (item.matchedAnime != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Source: ${item.matchedAnime!.url ?? 'unknown'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (isLowConfidence)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                'Low confidence match — please review',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.selected ? theme.colorScheme.primary : Colors.white24,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        item.selected ? Icons.check : Icons.add,
                        color: item.selected ? theme.colorScheme.onPrimary : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: FutureBuilder<ImportWatchlistPreview>(
                  future: _previewFuture,
                  builder: (context, snapshot) {
                    if (_items.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paste your anime list',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _controller,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: 'Naruto\nOne Piece\nAttack on Titan',
                              filled: true,
                              fillColor: Colors.white12,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _isAnalyzing ? null : _analyzeList,
                                  child: _isAnalyzing
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Analyze List'),
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                          ],
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review anime matches',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Confirm which titles should be saved. A match below 70% is flagged for review.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: InputDecoration(
                            labelText: 'Save As',
                            labelStyle: TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          dropdownColor: theme.colorScheme.surface,
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(value: 'plan_to_watch', child: Text('Plan to Watch')),
                            DropdownMenuItem(value: 'watching', child: Text('Watching')),
                            DropdownMenuItem(value: 'completed', child: Text('Completed')),
                            DropdownMenuItem(value: 'on_hold', child: Text('On Hold')),
                            DropdownMenuItem(value: 'dropped', child: Text('Dropped')),
                          ],
                          onChanged: _isSaving ? null : (value) {
                            if (value != null) {
                              setState(() {
                                _status = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: preview.items.length,
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              return _buildMatchCard(context, preview.items[index]);
                            },
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _isSaving ? null : _saveSelected,
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Save Selected'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
