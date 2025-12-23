import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FlashcardView extends StatefulWidget {
  // Update type to Future<dynamic> to match StudyHubScreen's _createRequest
  final Future<dynamic> Function(String) createRequest;
  const FlashcardView({super.key, required this.createRequest});
  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> {
  List<dynamic> _flashcards = [];
  bool _loadingCards = false;
  String _cardMode = "Standard";
  String? _errorMessage;

  Future<void> _fetchFlashcards() async {
    setState(() {
      _loadingCards = true;
      _errorMessage = null;
    });
    
    try {
      var request = await widget.createRequest('generate-flashcards');
      // Check if request is actually a MultipartRequest before accessing fields
      if (request is http.MultipartRequest) {
        request.fields['depth'] = _cardMode;
        var response = await http.Response.fromStream(await request.send());
        
        if (response.statusCode == 200) {
          setState(() {
            _flashcards = jsonDecode(response.body);
            _errorMessage = null;
          });
        } else {
          final errorBody = jsonDecode(response.body);
          setState(() => _errorMessage = errorBody['error'] ?? "Server Error");
        }
      } else {
         setState(() => _errorMessage = "Invalid request type");
      }

    } catch (e) {
      setState(() => _errorMessage = "Connection Failed: $e");
    } finally {
      setState(() => _loadingCards = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("AI Flashcards", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildOptionBtn("Quick", "Quick"), const SizedBox(width: 10), _buildOptionBtn("Standard", "Standard"), const SizedBox(width: 10), _buildOptionBtn("Deep", "Deep Study")]),
        const SizedBox(height: 20),
        ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Generate Cards"), onPressed: _fetchFlashcards),
        const SizedBox(height: 30),
        
        if (_loadingCards) const CircularProgressIndicator()
        else if (_errorMessage != null) 
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text("❌ Error: $_errorMessage", style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center),
          )
        else if (_flashcards.isEmpty) const Text("Select a mode and click Generate.", style: TextStyle(color: Colors.white54))
        else Expanded(child: FlashcardCarousel(cards: _flashcards)),
      ],
    );
  }

  Widget _buildOptionBtn(String label, String value) {
    bool isSelected = _cardMode == value;
    return InkWell(
      onTap: () => setState(() => _cardMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class FlashcardCarousel extends StatefulWidget {
  final List<dynamic> cards;
  const FlashcardCarousel({super.key, required this.cards});
  @override
  State<FlashcardCarousel> createState() => _FlashcardCarouselState();
}
class _FlashcardCarouselState extends State<FlashcardCarousel> {
  int _index = 0;
  bool _showFront = true;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _showFront = !_showFront),
          child: Container(
            width: 500, margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _showFront ? Colors.white : const Color(0xFF2D2B42), borderRadius: BorderRadius.circular(20)),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30.0), 
                child: Text(
                  _showFront ? widget.cards[_index]['front'] : widget.cards[_index]['back'], 
                  textAlign: TextAlign.center, 
                  style: TextStyle(fontSize: 24, color: _showFront ? Colors.black87 : Colors.white, fontWeight: _showFront ? FontWeight.bold : FontWeight.normal)
                )
              )
            ),
          ),
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.arrow_back), onPressed: _index > 0 ? () => setState(() { _index--; _showFront = true; }) : null),
        Text("Card ${_index + 1} / ${widget.cards.length}"),
        IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _index < widget.cards.length - 1 ? () => setState(() { _index++; _showFront = true; }) : null),
      ])
    ]);
  }
}