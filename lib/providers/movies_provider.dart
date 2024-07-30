import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
// import 'dart:convert' as convert;

import 'package:http/http.dart' as http;
import '../helpers/debouncer.dart';
import '../models/models.dart';
import '../models/search_response.dart';

class MoviesProvider extends ChangeNotifier {
  String _apiKey = 'cbd9191949c8af2889531d1a91646817';
  String _baseUrl = 'api.themoviedb.org';
  String _language = 'en-EN';

  List<Movie> onDisplayMovies = [];
  List<Movie> popularMovies = [];

  Map<int, List<Cast>> moviesCast = {};

  int _popularPage = 0;

  final debouncer = Debouncer(
    duration: const Duration(milliseconds: 500),
  );

  final StreamController<List<Movie>> _suggestionsStreamController =
      StreamController.broadcast();

  Stream<List<Movie>> get suggestionStream =>
      _suggestionsStreamController.stream;

  MoviesProvider() {
    if (kDebugMode) {
      print('MoviesProvider initialization');
    }
    getOnDisplayMovies();
    getPopularMovies();
  }
  Future<String> _getJsonData(String endpoint, [int query = 1]) async {
    final url = Uri.https(_baseUrl, endpoint, {
      'api_key': _apiKey,
      'language': _language,
      'query': '$query',
    });

    final response = await http.get(url);
    return response.body;
  }

  getOnDisplayMovies() async {
    final jsonData = await _getJsonData('3/movie/now_playing');
    // if (response.statusCode != 200) return print('error');
    final nowPlayingResponse = NowPlayingResponse.fromJson(jsonData);

    // final decodedData = json.decode(response.body) as Map<String, dynamic>;
    // print(nowPlayingResponse.results[0].title);
    onDisplayMovies = nowPlayingResponse.results;
    notifyListeners();
  }

  getPopularMovies() async {
    _popularPage++;
    final jsonData = await _getJsonData('3/movie/popular', _popularPage);
    // if (response.statusCode != 200) return print('error');
    final nowPlayingResponse = NowPlayingResponse.fromJson(jsonData);

    final popularResponse = PopularResponse.fromJson(jsonData);

    popularMovies = [...popularMovies, ...popularResponse.results];
    if (kDebugMode) {
      print('is searching...');
    }
    // print(popularMovies[0]);
    notifyListeners();
  }

  Future<List<Cast>> getMovieCast(int movieId) async {
    if (moviesCast.containsKey(movieId)) return moviesCast[movieId]!;
    if (kDebugMode) {
      print('requesting information from the server');
    }

    final jsonData = await _getJsonData('3/movie/$movieId/credits');
    final creditsResponse = CreditsResponse.fromJson(jsonData);
    moviesCast[movieId] = creditsResponse.cast;
    return creditsResponse.cast;
  }

  Future<List<Movie>> searchMovies(String query) async {
    final url = Uri.https(_baseUrl, '3/search/movie', {
      'api_key': _apiKey,
      'language': _language,
      'query': query,
    });

    final response = await http.get(url);
    final searchResponse = SearchResponse.fromJson(response.body);
    return searchResponse.results;
  }

  void getSuggestionsByQuery(String searchTerm) {
    debouncer.value = '';
    debouncer.onValue = (value) async {
      // print('You have value to search: $value');
      final results = await searchMovies(value);
      _suggestionsStreamController.add(results);
    };
    final timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      debouncer.value = searchTerm;
    });

    Future.delayed(const Duration(milliseconds: 301)).then((_) => timer.cancel());
  }
}
