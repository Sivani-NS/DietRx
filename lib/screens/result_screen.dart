import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/scan_result.dart';
import '../widgets/animated_leaf.dart';
import '../widgets/result_components.dart';
import '../widgets/animated_warning.dart';

class ResultScreen extends StatefulWidget {
  final ScanResult result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _loopController;

  late Animation<double> _imageScaleAnim;
  late Animation<double> _pillOpacityAnim;
  late Animation<Offset> _cardSlideAnim;
  late Animation<double> _cardOpacityAnim;

  @override
  void initState() {
    super.initState();

    // 1. Entrance Animations
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _imageScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _pillOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _cardSlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _cardOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();

    // 2. Infinite Loop Animations
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color primaryColor;
    Color pillColor;
    Color pillTextColor;
    String pillText;
    List<String> descriptionPoints = [];

    if (widget.result.isMissingData) {
      primaryColor = const Color(0xFFD97706);
      pillColor = const Color(0xFFFCD34D);
      pillTextColor = const Color(0xFF92400E);
      pillText = "UNKNOWN STATUS";
      descriptionPoints = [
        "Nutrition facts are missing from our database.",
        "We couldn't verify specific nutrients needed for your health profile.",
        "Please read the physical label carefully before consuming.",
      ];
    } else if (widget.result.isSafe) {
      primaryColor = const Color(0xFF4C7B33);
      pillColor = const Color(0xFF8CC63F);
      pillTextColor = Colors.white;
      pillText = "SAFE TO EAT";
      descriptionPoints = [
        "This product safely matches your dietary profile.",
        "It does not contain any ingredients restricted by your health conditions.",
        "No allergens matching your profile were detected.",
      ];
    } else {
      primaryColor = const Color(0xFFC11A1A);
      pillColor = const Color(0xFFE5A4A4);
      pillTextColor = const Color(0xFF7F1D1D);
      pillText = "NOT SAFE TO EAT";
      descriptionPoints = widget.result.warnings;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          // --- HEADER CURVE ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.elliptical(400, 150),
                ),
              ),
            ),
          ),

          // --- BACKGROUND ACCENT ICONS ---

          // 1. LOOPING LEAF ACCENTS (If Safe)
          if (widget.result.isSafe) ...[
            AnimatedLeaf(
              finalTop: MediaQuery.of(context).size.height * 0.20,
              left: 40,
              size: 40,
              delay: 0.0,
              landsOnLeft: true,
            ),
            AnimatedLeaf(
              finalTop: MediaQuery.of(context).size.height * 0.35,
              right: 40,
              size: 50,
              delay: 0.4,
              landsOnLeft: false,
            ),
          ],

          // 2. SHARP WARNING ICONS (If Not Safe)
          if (!widget.result.isSafe && !widget.result.isMissingData) ...[
            AnimatedWarningIcon(
              top: MediaQuery.of(context).size.height * 0.20,
              left: 40,
              size: 35,
              delay: 0.1,
              isLeft: true,
              color: pillColor,
            ),
            AnimatedWarningIcon(
              top: MediaQuery.of(context).size.height * 0.35,
              right: 40,
              size: 35,
              delay: 0.3,
              isLeft: false,
              color: pillColor,
            ),
          ],

          // --- BACK BUTTON & TITLE ---
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.result.productName.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- SCROLLABLE CONTENT ---
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.10,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // --- PRODUCT IMAGE  ---
                    ScaleTransition(
                      scale: _imageScaleAnim,
                      child: AnimatedBuilder(
                        animation: _loopController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -12 * _loopController.value),
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: widget.result.imageUrl != null
                                    ? Image.network(
                                        widget.result.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(
                                          Icons.fastfood,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.fastfood,
                                        size: 80,
                                        color: Colors.grey,
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- STATUS PILL ---
                    FadeTransition(
                      opacity: _pillOpacityAnim,
                      child: AnimatedBuilder(
                        animation: _loopController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (0.04 * _loopController.value),
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: pillColor,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: pillTextColor.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            pillText,
                            style: GoogleFonts.poppins(
                              color: pillTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- DESCRIPTION CARD & ALTERNATIVES  ---
                    SlideTransition(
                      position: _cardSlideAnim,
                      child: FadeTransition(
                        opacity: _cardOpacityAnim,
                        child: Column(
                          children: [
                            DescriptionCard(
                              pillColor: pillColor,
                              pillTextColor: pillTextColor,
                              descriptionPoints: descriptionPoints,
                            ),

                            if (!widget.result.isSafe ||
                                widget.result.isMissingData) ...[
                              const SizedBox(height: 20),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Safe Alternatives",
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              AlternativesList(
                                alternatives: widget.result.alternatives,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        backgroundColor: primaryColor,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
      ),
    );
  }
}
