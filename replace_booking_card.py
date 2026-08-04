import sys

file_path = "lib/features/consumer/presentation/consumer_shell.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Part 1: Replace build method grouping logic
start_build = -1
for i, line in enumerate(lines):
    if "return ListView.builder(" in line and "itemCount: confirmedBookings.length," in lines[i+2]:
        start_build = i
        break

if start_build != -1:
    new_build_lines = """              final groupedBookings = <String, List<Booking>>{};
              for (final b in confirmedBookings) {
                final key = b.transactionId ?? b.id;
                if (!groupedBookings.containsKey(key)) {
                  groupedBookings[key] = [];
                }
                groupedBookings[key]!.add(b);
              }
              final groups = groupedBookings.values.toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  return _buildGroupedBookingCard(context, ref, groups[i]);
                },
              );
"""
    # Delete the old ListView.builder (which was 8 lines)
    end_build = start_build + 8
    lines[start_build:end_build] = [new_build_lines]

# Part 2: Replace _buildBookingCard with _buildGroupedBookingCard
start_func = -1
for i, line in enumerate(lines):
    if "Widget _buildBookingCard(BuildContext context, WidgetRef ref, Booking b) {" in line:
        start_func = i
        break

if start_func != -1:
    # find end of function
    brace_count = 0
    end_func = -1
    for i in range(start_func, len(lines)):
        brace_count += lines[i].count('{') - lines[i].count('}')
        if brace_count == 0:
            end_func = i + 1
            break
            
    if end_func != -1:
        new_func = """  Widget _buildGroupedBookingCard(BuildContext context, WidgetRef ref, List<Booking> group) {
    if (group.isEmpty) return const SizedBox.shrink();
    
    final bFirst = group.first;
    final txnId = bFirst.transactionId ?? 'TXN-${bFirst.id.substring(0, min(6, bFirst.id.length)).toUpperCase()}';
    final totalAmount = group.fold<double>(0, (sum, b) => sum + b.amount);
    final consumerName = bFirst.consumerName;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRANSACTION: $txnId',
                style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'CONFIRMED',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...group.map((b) {
            String dText = b.eventDate ?? 'Flexible Date';
            try {
              if (b.eventDate != null) {
                final dt = DateTime.parse(b.eventDate!);
                dText = DateFormat('MMMM d, yyyy').format(dt);
              }
            } catch (_) {}
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b.category.toUpperCase()} • ${b.vendorName}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D103E)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('Date: $dText', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                      Text(
                        'Rs. ${b.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]},')}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              Text(
                'Rs. ${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]},')}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2D103E)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final auth = ref.read(authProvider);
                      await PdfReceiptService.generateAndShareReceipt(
                        transactionId: txnId,
                        userName: auth.displayName ?? auth.email ?? consumerName,
                        userEmail: auth.email ?? '',
                        ledgerCode: 'ORDER-${txnId.substring(max(0, txnId.length - 4))}',
                        paymentMethod: 'Credit Card (Paid & Verified)',
                        totalAmount: totalAmount,
                        items: group.map((b) => {
                          'category': b.category,
                          'vendorName': b.vendorName,
                          'eventDate': b.eventDate ?? 'Flexible Date',
                          'amount': b.amount,
                        }).toList(),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF2D103E)),
                    label: const Text(
                      'PDF Receipt',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2D103E)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                      foregroundColor: const Color(0xFF2D103E),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cancel Booking?'),
                        content: const Text('Are you sure you want to cancel this entire booking?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        for (final b in group) {
                          await FirebaseFirestore.instance.collection('bookings').doc(b.id).update({'status': 'Cancelled'});
                          
                          if (b.vendorId.isNotEmpty && b.eventDate != null) {
                            final norm = normalizeSingleDate(b.eventDate!);
                            if (norm != null) {
                              final availRef = FirebaseFirestore.instance.collection('vendor_availability').doc(b.vendorId);
                              final snap = await availRef.get();
                              if (snap.exists && snap.data() != null) {
                                final days = snap.data()!['days'] as List<dynamic>? ?? [];
                                final updatedDays = days.where((d) => (d is Map && d['date']?.toString() != norm)).toList();
                                await availRef.update({'days': updatedDays});
                              }
                            }
                          }

                          final inqSnap = await FirebaseFirestore.instance.collection('vendor_inquiries').where('vendorId', isEqualTo: b.vendorId).get();
                          for (final doc in inqSnap.docs) {
                            final dt = doc.data()['eventDate']?.toString() ?? doc.data()['detail']?.toString() ?? doc.data()['date']?.toString() ?? '';
                            if (b.eventDate != null && normalizeSingleDate(dt) == normalizeSingleDate(b.eventDate!)) {
                              await doc.reference.update({'status': 'Cancelled'});
                            }
                          }
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled successfully.')));
                        }
                      } catch (e) {
                        print("Error cancelling booking: $e");
                      }
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  label: const Text('Cancel', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
"""
        lines[start_func:end_func] = [new_func]
        print("Replacement successful")

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(lines)

