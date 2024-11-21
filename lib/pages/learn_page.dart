import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:handabatamae/widgets/header_footer/header_widget.dart';
import 'package:handabatamae/widgets/header_footer/footer_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:handabatamae/widgets/text_with_shadow.dart';
import 'package:responsive_framework/responsive_framework.dart';

class LearnPage extends StatefulWidget {
  final String selectedLanguage;
  final String category;
  final String title;
  final VoidCallback onBack;
  final ValueChanged<String> onLanguageChange;

  const LearnPage({
    super.key,
    required this.selectedLanguage,
    required this.category,
    required this.title,
    required this.onBack,
    required this.onLanguageChange,
  });

  @override
  LearnPageState createState() => LearnPageState();
}

class LearnPageState extends State<LearnPage> {
  Map<String, dynamic>? _content;
  bool _isLoading = true;
  late String _currentLanguage;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.selectedLanguage;
    _loadContent();
  }

  @override
  void didUpdateWidget(LearnPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLanguage != oldWidget.selectedLanguage) {
      _handleLanguageChange(widget.selectedLanguage);
    }
  }

  void _handleLanguageChange(String newLanguage) {
    print('🌐 Language changed to: $newLanguage');
    setState(() {
      _currentLanguage = newLanguage;
      _isLoading = true;
    });
    _loadContent();
    widget.onLanguageChange(newLanguage);
  }

  Future<void> _loadContent() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/localization/learn/${_currentLanguage}.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final Map<String, dynamic> categoryData = jsonData[widget.category];
      setState(() {
        _content = categoryData[widget.title];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading content: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_content == null) {
      return Center(
        child: Text(
          'Content not found',
          style: GoogleFonts.rubik(color: Colors.white),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.black,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWithShadow(
                          text: _content!['title'],
                          fontSize: 48,
                        ),
                        const SizedBox(height: 20),
                        ..._buildContentSections(),
                        if (_content!.containsKey('references')) ...[
                          const SizedBox(height: 40),
                          Text(
                            widget.selectedLanguage == 'en' ? 'References' : 'Mga Sanggunian',
                            style: GoogleFonts.rubik(
                              fontSize: 32,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._buildReferences(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Spacer(),
              FooterWidget(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildContentSections() {
    List<Widget> widgets = [];
    
    for (var section in _content!['content']) {
      // Special handling for "Did you know?" sections
      if (section.containsKey('heading') && 
          (section['heading'] == 'Did you know?' || 
           section['heading'] == 'Alam mo ba?')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: const Color(0xFF351B61).withOpacity(0.1),
              border: Border.all(
                color: const Color(0xFF351B61),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  widget.selectedLanguage == 'en' 
                      ? 'assets/characters/CuriousKladis.png'
                      : 'assets/characters/CuriousKloud.png',
                  height: 60,
                  width: 60,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['heading'],
                        style: GoogleFonts.rubik(
                          fontSize: 24,
                          color: const Color(0xFF351B61),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDescription(section['description']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        continue; // Skip normal processing for this section
      }

      // Handle section heading
      if (section.containsKey('heading') && section['heading'].isNotEmpty) {
        widgets.add(_buildHeading(section['heading']));
      }

      // Handle description with HTML
      if (section.containsKey('description')) {
        widgets.add(_buildDescription(section['description']));
      }

      // Handle lists with proper nesting
      if (section.containsKey('list')) {
        // Check if list contains objects with subheadings
        if (section['list'] is List && section['list'].isNotEmpty) {
          for (var listItem in section['list']) {
            if (listItem is Map<String, dynamic>) {
              // Handle subheading sections (Before, During, After)
              if (listItem.containsKey('subheading')) {
                widgets.add(
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, top: 15.0, bottom: 5.0),
                    child: Text(
                      listItem['subheading'],
                      style: GoogleFonts.rubik(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );

                // Handle the list under the subheading
                if (listItem.containsKey('list')) {
                  widgets.addAll(_buildList(listItem['list']));
                }
              } else {
                // Handle other types of list items
                widgets.add(_buildComplexListItem(listItem));
              }
            } else {
              // Handle simple string list items
              widgets.add(_buildSimpleListItem(listItem.toString()));
            }
          }
        }
      }

      // Handle JSON data display
      if (section.containsKey('json')) {
        widgets.add(_buildJsonData(section['json']));
      }

      // Handle table
      if (section.containsKey('table')) {
        widgets.add(_buildTable(section['table']));
      }

      // Handle images
      if (section.containsKey('img')) {
        widgets.add(_buildImage(section['img']));
      }

      // Handle details
      if (section.containsKey('details')) {
        widgets.add(_buildDetails(section['details']));
      }
    }

    return widgets;
  }

  Widget _buildHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: GoogleFonts.rubik(
          fontSize: 32,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDescription(String text) {
    print('🖼️ Building description with HTML: ${text.substring(0, min(100, text.length))}...');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Html(
        data: text,
        style: {
          "body": Style(
            color: Colors.black,
            fontSize: FontSize(16),
            fontFamily: 'Rubik',
          ),
          "p": Style(margin: Margins.zero),
          "figure": Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "figcaption": Style(
            color: Colors.black54,
            fontSize: FontSize(14),
            fontStyle: FontStyle.italic,
            textAlign: TextAlign.center,
          ),
          "img": Style(
            width: Width(double.infinity),
            backgroundColor: Colors.transparent,
          ),
        },
      ),
    );
  }

  Widget _buildJsonData(Map<String, dynamic> json) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: json.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${entry.key}:',
                      style: GoogleFonts.rubik(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${entry.value}',
                      style: GoogleFonts.rubik(color: Colors.black),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTable(Map<String, dynamic> tableData) {
    final headers = (tableData['headers'] as List).cast<String>();
    final rows = (tableData['rows'] as List).cast<Map<String, dynamic>>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: GoogleFonts.rubik(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          dataTextStyle: GoogleFonts.rubik(
            color: Colors.black,
            fontSize: 14,
          ),
          columns: headers.map((header) {
            return DataColumn(label: Text(header));
          }).toList(),
          rows: rows.map((row) {
            return DataRow(
              cells: headers.map((header) {
                return DataCell(Text('${row[header] ?? ""}'));
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _buildList(List items) {
    return items.map((item) {
      if (item is String) {
        return _buildSimpleListItem(item);
      } else if (item is Map<String, dynamic>) {
        // Handle items with subheading and list
        if (item.containsKey('subheading') && item.containsKey('list')) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20.0, top: 15.0, bottom: 5.0),
                child: Text(
                  item['subheading'],
                  style: GoogleFonts.rubik(
                    fontSize: 20,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...(_buildList(item['list'] as List)),
            ],
          );
        }

        // Handle items with title and sublist
        if (item.containsKey('title') && item.containsKey('sublist')) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 40.0, top: 10.0),
                child: Text(
                  item['title'],
                  style: GoogleFonts.rubik(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              ..._buildList(item['sublist'] as List),
            ],
          );
        }

        // Handle other complex list items
        return _buildComplexListItem(item);
      }
      return const SizedBox.shrink();
    }).toList();
  }

  Widget _buildSimpleListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.black)),
          Expanded(
            child: Html(
              data: text,
              style: {
                "body": Style(
                  color: Colors.black,
                  fontSize: FontSize(16),
                  fontFamily: 'Rubik',
                  margin: Margins.zero,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplexListItem(Map<String, dynamic> item) {
    List<Widget> widgets = [];

    if (item.containsKey('img')) {
      print('🖼️ Found image in list item: ${item['img']}');
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Image.asset(
            item['img'],
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error loading list image: $error');
              return const SizedBox();
            },
          ),
        ),
      );
    }

    if (item.containsKey('details')) {
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (item['details'] as List).map((detail) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (detail['title'] != null)
                    Text(
                      detail['title'],
                      style: GoogleFonts.rubik(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  if (detail['description'] != null)
                    Text(
                      detail['description'],
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    if (item.containsKey('title')) {
      widgets.add(
        Text(
          item['title'],
          style: GoogleFonts.rubik(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (item.containsKey('description')) {
      widgets.add(
        Html(
          data: item['description'],
          style: {
            "body": Style(
              color: Colors.black,
              fontSize: FontSize(16),
              fontFamily: 'Rubik',
            ),
          },
        ),
      );
    }

    if (item.containsKey('sublist')) {
      widgets.addAll(_buildList((item['sublist'] as List)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    print('🖼️ Building direct image: $imagePath');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading direct image $imagePath: $error');
            print('Stack trace: $stackTrace');
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildDetails(List<dynamic> details) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details.map((detail) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail['title'] != null)
                  Text(
                    detail['title'],
                    style: GoogleFonts.rubik(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (detail['description'] != null)
                  Text(
                    detail['description'],
                    style: GoogleFonts.rubik(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildReferences() {
    return (_content!['references'] as List).map((reference) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
        child: Text(
          reference,
          style: GoogleFonts.rubik(
            fontSize: 14,
            color: Colors.black,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C1B47),
      body: ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
        child: MaxWidthBox(
          maxWidth: 1200,
          child: ResponsiveScaledBox(
            width: ResponsiveValue<double>(context, conditionalValues: [
              const Condition.equals(name: MOBILE, value: 450),
              const Condition.between(start: 800, end: 1100, value: 800),
              const Condition.between(start: 1000, end: 1200, value: 1000),
            ]).value,
            child: Stack(
              children: [
                SvgPicture.asset(
                  'assets/backgrounds/background.svg',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Column(
                  children: [
                    HeaderWidget(
                      selectedLanguage: _currentLanguage,
                      onBack: widget.onBack,
                      onChangeLanguage: _handleLanguageChange,
                    ),
                    Expanded(
                      child: _buildContent(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
