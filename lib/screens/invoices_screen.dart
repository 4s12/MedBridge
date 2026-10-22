import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import '../services/db_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Shows all invoices for a patient.
class InvoicesScreen extends StatelessWidget {
  final String patientId;
  const InvoicesScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Invoices')),
      body: Centered(
        maxWidth: 640,
        child: StreamBuilder<List<Snap>>(
          stream: DB.patientInvoices(patientId),
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  icon: Icons.error_outline,
                  message: 'Could not load invoices.');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final invoices = snap.data!;
            if (invoices.isEmpty) {
              return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'No invoices yet.\nBills will appear here after booking.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final inv = Invoice.fromDoc(invoices[i]);
                return InvoiceCard(invoice: inv);
              },
            );
          },
        ),
      ),
    );
  }
}

/// Shows all invoices for a doctor.
class DoctorInvoicesScreen extends StatelessWidget {
  final String doctorId;
  const DoctorInvoicesScreen({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Invoices')),
      body: Centered(
        maxWidth: 720,
        child: StreamBuilder<List<Snap>>(
          stream: DB.doctorInvoices(doctorId),
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  icon: Icons.error_outline,
                  message: 'Could not load invoices.');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final invoices = snap.data!;
            if (invoices.isEmpty) {
              return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message:
                      'No invoices yet.\nBills are created automatically when patients book appointments.');
            }

            // Summary row
            final all = invoices.map((d) => Invoice.fromDoc(d)).toList();
            final paid = all.where((i) => i.isPaid).length;
            final unpaid = all.where((i) => i.isPending).length;
            final totalEarnings =
                all.where((i) => i.isPaid).fold(0, (s, i) => s + i.fee);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      _summaryCard('Total', '${all.length}',
                          Icons.receipt_long, Colors.blue),
                      const SizedBox(width: 10),
                      _summaryCard('Paid', '$paid', Icons.check_circle,
                          Colors.green),
                      const SizedBox(width: 10),
                      _summaryCard(
                          'Pending', '$unpaid', Icons.pending, Colors.orange),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Card(
                    color: kPrimary.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_rupee, color: kPrimary),
                          const SizedBox(width: 8),
                          Text('Total Earnings: ₹$totalEarnings',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: kPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: all.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      return InvoiceCard(
                          invoice: all[i], showPatient: true);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card widget for a single invoice.
class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final bool showPatient;
  const InvoiceCard({super.key, required this.invoice, this.showPatient = false});

  Color get _statusColor {
    switch (invoice.status) {
      case 'paid':
        return Colors.green;
      case 'cancelled':
        return Colors.red.shade400;
      default:
        return Colors.orange;
    }
  }

  IconData get _statusIcon {
    switch (invoice.status) {
      case 'paid':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showPatient
                            ? invoice.patientName
                            : drName(invoice.doctorName),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text('${prettyDate(invoice.date)} · ${invoice.timeSlot}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 14, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(
                        invoice.status.toUpperCase(),
                        style: TextStyle(
                            color: _statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Consultation Fee',
                    style: TextStyle(color: Colors.grey.shade600)),
                Text('₹${invoice.fee}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invoice ID',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11)),
                Text(invoice.id.substring(0, 8).toUpperCase(),
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
