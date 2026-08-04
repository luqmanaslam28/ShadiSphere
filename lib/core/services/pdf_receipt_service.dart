import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfReceiptService {
  static Future<Uint8List> generateReceiptPdf({
    required String transactionId,
    required String userName,
    required String userEmail,
    required String ledgerCode,
    required String paymentMethod,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();

    // Color Palette
    final deepPurple = PdfColor.fromInt(0xFF2D103E);
    final gold = PdfColor.fromInt(0xFFD4AF37);
    final goldLight = PdfColor.fromInt(0xFFF5ECD0);
    final cream = PdfColor.fromInt(0xFFFAF7F2);
    final warmGrey = PdfColor.fromInt(0xFF6B5E6E);
    final lightLine = PdfColor.fromInt(0xFFE8E0D8);
    final dateStr = DateFormat('MMMM d, yyyy • hh:mm a').format(DateTime.now());

    String formatCurrency(double val) {
      return 'Rs. ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    }

    final formattedTotal = formatCurrency(totalAmount);

    // Fonts
    pw.Font fontDisplay;
    pw.Font fontRegular;
    pw.Font fontBold;
    pw.Font fontItalic;
    pw.Font fontMedium;

    try {
      fontDisplay = await PdfGoogleFonts.playfairDisplayBold();
      fontRegular = await PdfGoogleFonts.interRegular();
      fontBold = await PdfGoogleFonts.interBold();
      fontMedium = await PdfGoogleFonts.interMedium();
      fontItalic = await PdfGoogleFonts.interItalic();
    } catch (_) {
      fontDisplay = pw.Font.helveticaBold();
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      fontMedium = pw.Font.helveticaBold();
      fontItalic = pw.Font.helveticaOblique();
    }

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/royal_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── TOP HEADER BAR ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: pw.BoxDecoration(
                  color: deepPurple,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Row(
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 44,
                            height: 44,
                            margin: const pw.EdgeInsets.only(right: 16),
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              border: pw.Border.all(color: gold, width: 1.5),
                            ),
                            child: pw.ClipOval(child: pw.Image(logoImage)),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'SHADISPHERE',
                              style: pw.TextStyle(font: fontDisplay, color: gold, fontSize: 22, letterSpacing: 3),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'Wedding Booking Receipt',
                              style: pw.TextStyle(font: fontRegular, color: PdfColors.white, fontSize: 9, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Status badge
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: gold,
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 7,
                            height: 7,
                            decoration: pw.BoxDecoration(
                              color: deepPurple,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            'PAID',
                            style: pw.TextStyle(font: fontBold, color: deepPurple, fontSize: 9, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 28),

              // ── INVOICE METADATA: 2-column layout ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Billed To
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO', style: pw.TextStyle(font: fontBold, fontSize: 8, color: gold, letterSpacing: 2)),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          userName.isNotEmpty ? userName : 'Valued Customer',
                          style: pw.TextStyle(font: fontBold, fontSize: 14, color: deepPurple),
                        ),
                        if (userEmail.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(userEmail, style: pw.TextStyle(font: fontRegular, fontSize: 9, color: warmGrey)),
                        ],
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: goldLight,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            ledgerCode,
                            style: pw.TextStyle(font: fontMedium, fontSize: 8, color: deepPurple, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: Transaction Details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE DETAILS', style: pw.TextStyle(font: fontBold, fontSize: 8, color: gold, letterSpacing: 2)),
                        pw.SizedBox(height: 8),
                        _metaRow('Transaction ID', transactionId, fontRegular, fontMedium, warmGrey, deepPurple),
                        pw.SizedBox(height: 5),
                        _metaRow('Date', dateStr, fontRegular, fontMedium, warmGrey, warmGrey),
                        pw.SizedBox(height: 5),
                        _metaRow('Payment', paymentMethod, fontRegular, fontMedium, warmGrey, warmGrey),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // ── GOLD DIVIDER ──
              pw.Container(height: 1.5, color: gold),

              pw.SizedBox(height: 24),

              // ── SECTION TITLE ──
              pw.Text(
                'Booking Summary',
                style: pw.TextStyle(font: fontDisplay, fontSize: 16, color: deepPurple),
              ),
              pw.SizedBox(height: 14),

              // ── ITEMS TABLE ──
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: deepPurple,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(8),
                    topRight: pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text('SERVICE', style: pw.TextStyle(font: fontBold, color: gold, fontSize: 8, letterSpacing: 1))),
                    pw.Expanded(flex: 3, child: pw.Text('VENDOR & DESCRIPTION', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 8, letterSpacing: 1))),
                    pw.Expanded(flex: 2, child: pw.Text('EVENT DATE', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 8, letterSpacing: 1))),
                    pw.Expanded(flex: 2, child: pw.Text('AMOUNT', style: pw.TextStyle(font: fontBold, color: gold, fontSize: 8, letterSpacing: 1), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),
              // Data Rows
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final amt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                final amtStr = formatCurrency(amt);
                final isLast = index == items.length - 1;
                
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: index % 2 == 0 ? PdfColors.white : cream,
                    border: isLast
                        ? pw.Border.all(color: lightLine, width: 0.5)
                        : pw.Border(
                            left: pw.BorderSide(color: lightLine, width: 0.5),
                            right: pw.BorderSide(color: lightLine, width: 0.5),
                            bottom: pw.BorderSide(color: lightLine, width: 0.5),
                          ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF3D1A52),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            item['category']?.toString() ?? 'Service',
                            style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 8),
                          child: pw.Text(
                            item['vendorName']?.toString() ?? 'Vendor Service',
                            style: pw.TextStyle(font: fontMedium, fontSize: 9, color: PdfColors.grey800),
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          item['eventDate']?.toString() ?? 'Flexible',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9, color: warmGrey),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          amtStr,
                          style: pw.TextStyle(font: fontBold, fontSize: 10, color: deepPurple),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 20),

              // ── TOTALS SECTION (right-aligned) ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 260,
                    child: pw.Column(
                      children: [
                        // Subtotal
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Subtotal', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: warmGrey)),
                              pw.Text(formattedTotal, style: pw.TextStyle(font: fontMedium, fontSize: 10, color: PdfColors.grey800)),
                            ],
                          ),
                        ),
                        // Platform fee
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Platform Fee', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: warmGrey)),
                              pw.Text('Included', style: pw.TextStyle(font: fontMedium, fontSize: 10, color: PdfColor.fromInt(0xFF2E8B57))),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        // Divider
                        pw.Container(height: 1, color: lightLine),
                        pw.SizedBox(height: 10),
                        // Grand Total
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: pw.BoxDecoration(
                            color: deepPurple,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('TOTAL PAID', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white, letterSpacing: 1)),
                              pw.Text(formattedTotal, style: pw.TextStyle(font: fontDisplay, fontSize: 16, color: gold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // ── FOOTER ──
              // Gold thin line
              pw.Container(height: 0.5, color: goldLight),
              pw.SizedBox(height: 16),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: guarantee text
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 16,
                              height: 16,
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                color: gold,
                              ),
                              child: pw.Center(
                                child: pw.Text('✓', style: pw.TextStyle(font: fontBold, fontSize: 10, color: deepPurple)),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Text('Verified & Secured by ShadiSphere', style: pw.TextStyle(font: fontBold, fontSize: 9, color: deepPurple)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'This receipt serves as official proof of payment and booking confirmation.',
                          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: warmGrey),
                        ),
                        pw.Text(
                          'For support, contact support@shadisphere.com',
                          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: warmGrey),
                        ),
                      ],
                    ),
                  ),
                  // Right: branding
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('www.shadisphere.com', style: pw.TextStyle(font: fontBold, fontSize: 9, color: deepPurple, letterSpacing: 0.5)),
                      pw.SizedBox(height: 3),
                      pw.Text('Making Your Wedding Dreams Come True', style: pw.TextStyle(font: fontItalic, fontSize: 8, color: gold)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _metaRow(String label, String value, pw.Font fontRegular, pw.Font fontMedium, PdfColor labelColor, PdfColor valueColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('$label:  ', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: labelColor)),
        pw.Text(value, style: pw.TextStyle(font: fontMedium, fontSize: 9, color: valueColor)),
      ],
    );
  }

  static Future<void> generateAndShareReceipt({
    required String transactionId,
    required String userName,
    required String userEmail,
    required String ledgerCode,
    required String paymentMethod,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      transactionId: transactionId,
      userName: userName,
      userEmail: userEmail,
      ledgerCode: ledgerCode,
      paymentMethod: paymentMethod,
      totalAmount: totalAmount,
      items: items,
    );

    final filename = 'ShadiSphere_Receipt_$transactionId.pdf';

    // 2. Mobile & Native Printing Fallback
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: filename,
      );
    } catch (_) {
      try {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: filename,
        );
      } catch (_) {}
    }
  }
}
