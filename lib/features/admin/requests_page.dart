import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:book_hub/features/admin/admin_guard.dart';
import 'package:book_hub/features/auth/auth_provider.dart';
import 'requests_models.dart';
import 'requests_providers.dart';

/// Generic page used by both:
/// - AdminRequestsPage (fixedType: 'LOOKUP')
/// - AdminSubmissionsPage (fixedType: 'CONTRIBUTION')
class RequestsPage extends ConsumerStatefulWidget {
  final String? fixedType; // "LOOKUP" or "CONTRIBUTION"
  final String? fixedStatus; // optional
  const RequestsPage({super.key, this.fixedType, this.fixedStatus});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // kick first load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ⬇️ If token isn’t there yet (cold start), finish auto-login once here
      if (ref.read(authProvider).token == null) {
        await ref.read(authProvider.notifier).tryAutoLogin();
      }
      // Now that we're sure we're logged in, load the data
      await ref
          .read(adminRequestsControllerProvider(widget.fixedType).notifier)
          .loadFirstPage();
    });

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        ref
            .read(adminRequestsControllerProvider(widget.fixedType).notifier)
            .loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminRequestsControllerProvider(widget.fixedType));
    final ctrl = ref.read(
      adminRequestsControllerProvider(widget.fixedType).notifier,
    );

    final title =
        widget.fixedType == 'CONTRIBUTION'
            ? 'Review Submissions'
            : 'Manage Requests';

    // ⬇️ Wrap the whole page with the guard
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: RefreshIndicator(
          onRefresh: () => ctrl.loadFirstPage(),
          child: Column(
            children: [
              _StatusChips(
                current: state.filter.status,
                onChanged: (s) => ctrl.changeStatusFilter(s),
                showAll: widget.fixedStatus == null,
              ),
              if (state.loading && state.items.isEmpty)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.error != null && state.items.isEmpty)
                Expanded(
                  child: _ErrorView(
                    message: state.error!,
                    onRetry: ctrl.loadFirstPage,
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: _scroll,
                    itemCount: state.items.length + (state.loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final r = state.items[index];
                      return _RequestTile(
                        dto: r,
                        onApprove: () async {
                          String? createdBookId;
                          // Only ask for createdBookId if contribution (you may skip if your backend accepts null)
                          if (r.requestType == BookRequestType.CONTRIBUTION) {
                            createdBookId = await _askForCreatedBookId(context);
                          }
                          try {
                            await ctrl.approve(
                              r.id!,
                              createdBookId: createdBookId,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Approved')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Approve failed: $e')),
                              );
                            }
                          }
                        },
                        onReject: () async {
                          final reason = await _askForReason(context);
                          if (reason == null || reason.trim().isEmpty) return;
                          try {
                            await ctrl.reject(r.id!, reason: reason.trim());
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Rejected')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reject failed: $e')),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  final String current;
  final bool showAll;
  final ValueChanged<String> onChanged;
  const _StatusChips({
    required this.current,
    required this.onChanged,
    this.showAll = true,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = const ['PENDING', 'APPROVED', 'REJECTED'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children:
            statuses.map((s) {
              final selected = current == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: showAll ? (_) => onChanged(s) : null,
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final BookRequestResponseDto dto;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestTile({
    required this.dto,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final type =
        dto.requestType == BookRequestType.CONTRIBUTION
            ? 'CONTRIBUTION'
            : 'LOOKUP';
    final status = dto.status.name;

    return ListTile(
      title: Text(dto.title ?? '(no title)'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dto.author != null && dto.author!.isNotEmpty)
            Text('Author: ${dto.author}'),
          Text('Type: $type   •   Status: $status'),
          if (dto.isbn != null && dto.isbn!.isNotEmpty)
            Text('ISBN: ${dto.isbn}'),
          if (dto.description != null && dto.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                dto.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: _ActionButtons(
        status: dto.status,
        onApprove: onApprove,
        onReject: onReject,
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final BookRequestStatus status;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ActionButtons({
    required this.status,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final canAct = status == BookRequestStatus.PENDING;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Approve',
          icon: const Icon(Icons.check_circle_outline),
          onPressed: canAct ? onApprove : null,
        ),
        IconButton(
          tooltip: 'Reject',
          icon: const Icon(Icons.cancel_outlined),
          onPressed: canAct ? onReject : null,
        ),
      ],
    );
  }
}

Future<String?> _askForReason(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Reject reason'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter reason'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Reject'),
            ),
          ],
        ),
  );
}

Future<String?> _askForCreatedBookId(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Created Book ID (optional)'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Book ID if already created',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.pop(
                    context,
                    controller.text.trim().isEmpty
                        ? null
                        : controller.text.trim(),
                  ),
              child: const Text('OK'),
            ),
          ],
        ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
