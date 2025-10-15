import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/frequent_partners_service.dart';
import '../utils/ui_helper.dart';

class FrequentPartnersList extends StatefulWidget {
  final VoidCallback? onPartnerSelected;
  final VoidCallback? onPairingStatusChanged;

  const FrequentPartnersList({
    super.key,
    this.onPartnerSelected,
    this.onPairingStatusChanged,
  });

  @override
  State<FrequentPartnersList> createState() => _FrequentPartnersListState();
}

class _FrequentPartnersListState extends State<FrequentPartnersList> {
  final FrequentPartnersService _frequentPartnersService = FrequentPartnersService();
  List<PartnerHistoryEntry> _frequentPartners = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFrequentPartners();
  }

  Future<void> _loadFrequentPartners() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final partners = await _frequentPartnersService.getFrequentPartners(user.id);
      if (!mounted) return;
      setState(() {
        _frequentPartners = partners;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load frequent partners: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _quickRePair(PartnerHistoryEntry partner) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        UIHelper.showError(context, 'User not logged in');
        return;
      }

      await _frequentPartnersService.quickRePair(user.id, partner.partnerId);
      
      if (mounted) {
        UIHelper.showSnack(context, 'Successfully paired with ${partner.partnerName}!');
        widget.onPartnerSelected?.call();
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, 'Failed to re-pair: $e');
      }
    }
  }

  Future<void> _toggleFavorite(PartnerHistoryEntry partner) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final isFavorite = await _frequentPartnersService.togglePartnerFavorite(
        user.id, 
        partner.partnerId
      );

      if (mounted) {
        UIHelper.showSnack(
          context, 
          isFavorite 
            ? '${partner.partnerName} added to favorites' 
            : '${partner.partnerName} removed from favorites'
        );
        
        // Reload the list to reflect changes
        _loadFrequentPartners();
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, 'Failed to update favorite: $e');
      }
    }
  }

  Future<void> _removeFromHistory(PartnerHistoryEntry partner) async {
    final confirmed = await UIHelper.confirm(
      context,
      title: 'Remove Partner',
      message: 'Remove ${partner.partnerName} from your frequent partners list?',
      confirmText: 'Remove',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await _frequentPartnersService.removePartnerFromHistory(
        user.id, 
        partner.partnerId
      );

      if (mounted) {
        UIHelper.showSnack(context, '${partner.partnerName} removed from history');
        _loadFrequentPartners();
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, 'Failed to remove partner: $e');
      }
    }
  }

  String _formatLastPaired(DateTime lastPaired) {
    final now = DateTime.now();
    final difference = now.difference(lastPaired);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFrequentPartners,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_frequentPartners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Frequent Partners',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Partners you pair with frequently will appear here for quick access.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFrequentPartners,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _frequentPartners.length,
        itemBuilder: (context, index) {
          final partner = _frequentPartners[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: partner.isFavorite 
                  ? Colors.orange 
                  : Colors.blue,
                child: Icon(
                  partner.isFavorite ? Icons.favorite : Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      partner.partnerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (partner.isFavorite)
                    const Icon(
                      Icons.star,
                      color: Colors.orange,
                      size: 16,
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paired ${partner.pairingCount} time${partner.pairingCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Last paired: ${_formatLastPaired(partner.lastPairedAt)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 're-pair':
                      _quickRePair(partner);
                      break;
                    case 'favorite':
                      _toggleFavorite(partner);
                      break;
                    case 'remove':
                      _removeFromHistory(partner);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 're-pair',
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16),
                        const SizedBox(width: 8),
                        const Text('Re-pair'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'favorite',
                    child: Row(
                      children: [
                        Icon(
                          partner.isFavorite ? Icons.star_border : Icons.star,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(partner.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Remove from history', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => _quickRePair(partner),
            ),
          );
        },
      ),
    );
  }
}
