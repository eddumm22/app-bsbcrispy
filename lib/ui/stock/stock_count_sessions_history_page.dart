import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/stock_count_session.dart';
import '../../models/stock_count_session_item.dart';
import '../../services/stock_count_service.dart';
import '../../state/auth_controller.dart';
import 'stock_count_session_detail_page.dart';

class StockCountSessionsHistoryPage extends StatelessWidget {
  const StockCountSessionsHistoryPage({super.key});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.user?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não autenticado.')),
      );
    }

    final stockService = context.read<StockCountService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Contagens'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<StockCountSession>>(
            stream: stockService.watchStockCountSessions(uid: uid),
            builder: (context, sessionsSnapshot) {
              if (sessionsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final sessions = sessionsSnapshot.data ?? [];

              if (sessions.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma contagem registrada ainda.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final session = sessions[index];

                  return Card(
                    elevation: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StockCountSessionDetailPage(
                              sessionId: session.id,
                              sessionDate: session.date,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data: ${_formatDate(session.date)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            StreamBuilder<List<StockCountSessionItem>>(
                              stream: stockService.watchStockCountItemsInSession(
                                uid: uid,
                                sessionId: session.id,
                              ),
                              builder: (context, itemsSnapshot) {
                                if (itemsSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text(
                                        'Itens contados',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ],
                                  );
                                }

                                final count = itemsSnapshot.data?.length ?? 0;

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Itens contados',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      count.toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

