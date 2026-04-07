import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_rating.dart';
import '../../services/rating_service.dart';
import '../../services/user_profile_service.dart';
import '../../state/auth_controller.dart';

class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  int? _pickedStars;
  bool _saving = false;
  Future<Map<String, dynamic>?>? _profileFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileFuture ??= () {
      final uid = context.read<AuthController>().user?.uid;
      if (uid == null) return Future<Map<String, dynamic>?>.value(null);
      return context.read<UserProfileService>().getUserProfile(uid);
    }();
  }

  String _displayNameFromProfile(Map<String, dynamic>? data, String? email) {
    if (data == null) return email?.split('@').first ?? 'Usuário';
    final first = (data['firstName'] as String?)?.trim() ?? '';
    final last = (data['lastName'] as String?)?.trim() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return email?.split('@').first ?? 'Usuário';
  }

  String _formatDatePtBr(DateTime? d) {
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String _formatAverage(double? avg) {
    if (avg == null) return '—';
    return avg.toStringAsFixed(1).replaceAll('.', ',');
  }

  int _starsToShow(AppRating? mine) {
    if (_pickedStars != null) return _pickedStars!;
    return mine?.stars ?? 5;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.user?.uid;
    final email = auth.user?.email;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (uid == null) {
      return const Center(child: Text('Usuário não autenticado.'));
    }

    final ratingService = context.read<RatingService>();
    return SafeArea(
      child: StreamBuilder<List<AppRating>>(
          stream: ratingService.watchRatings(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText(
                    'Não foi possível carregar as avaliações.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final list = snapshot.data ?? [];
            final average = AppRating.averageFor(list);
            AppRating? mine;
            for (final r in list) {
              if (r.uid == uid) {
                mine = r;
                break;
              }
            }

            return FutureBuilder<Map<String, dynamic>?>(
              future: _profileFuture,
              builder: (context, profileSnap) {
                final displayName =
                    _displayNameFromProfile(profileSnap.data, email);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Avaliação',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                'Nota média',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _formatAverage(average),
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                    ),
                                  ),
                                  if (average != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.star_rounded,
                                        color: Colors.amber.shade700, size: 36),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                list.isEmpty
                                    ? 'Ainda não há avaliações'
                                    : '${list.length} avaliação${list.length == 1 ? '' : 'ões'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sua avaliação',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mine != null
                            ? 'Toque nas estrelas para alterar e confirme abaixo.'
                            : 'Quantas estrelas você dá para o sistema?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FittedBox(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starIndex = index + 1;
                              final selected = _starsToShow(mine);
                              final filled = starIndex <= selected;
                              return IconButton(
                                iconSize: 44,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                onPressed: _saving
                                    ? null
                                    : () {
                                        setState(() => _pickedStars = starIndex);
                                      },
                                icon: Icon(
                                  filled
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: filled
                                      ? Colors.amber.shade700
                                      : Colors.grey.shade400,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final stars = _starsToShow(mine);
                                setState(() => _saving = true);
                                try {
                                  await ratingService.saveRating(
                                    uid: uid,
                                    userName: displayName,
                                    stars: stars,
                                  );
                                  if (!context.mounted) return;
                                  setState(() => _saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Obrigado pela sua avaliação!',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setState(() => _saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Não foi possível salvar: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(_saving ? 'Salvando…' : 'Confirmar avaliação'),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Todas as avaliações',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (list.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Nenhuma avaliação ainda. Seja o primeiro!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...list.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  r.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Data: ${_formatDatePtBr(r.updatedAt ?? r.createdAt)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${r.stars}',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: primary,
                                      ),
                                    ),
                                    Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber.shade700,
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
    );
  }
}

