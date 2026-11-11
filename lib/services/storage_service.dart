import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../models/recipe_book.dart';

class StorageService {
  static const String _booksKey = 'recipe_books_key';
  static const String _recipesKey = 'recipes_key';

  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  Future<List<RecipeBook>> getBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_booksKey);
    if (data == null) {
      final defaultBook = RecipeBook(
        id: 'default',
        name: 'My Favorites',
        description: 'Default collection of favorite recipes',
      );
      await saveBooks([defaultBook]);
      return [defaultBook];
    }
    final List<dynamic> list = jsonDecode(data);
    return list.map((e) => RecipeBook.fromJson(e)).toList();
  }

  Future<void> saveBooks(List<RecipeBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(books.map((e) => e.toJson()).toList());
    await prefs.setString(_booksKey, data);
  }

  Future<void> saveBook(RecipeBook book) async {
    final books = await getBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      books[index] = book;
    } else {
      books.add(book);
    }
    await saveBooks(books);
  }

  Future<void> deleteBook(String bookId) async {
    final books = await getBooks();
    books.removeWhere((b) => b.id == bookId);
    await saveBooks(books);

    // Also remove recipes in this book
    final recipes = await getRecipes();
    recipes.removeWhere((r) => r.bookId == bookId);
    await saveRecipes(recipes);
  }

  Future<List<Recipe>> getRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_recipesKey);
    if (data == null) return [];
    final List<dynamic> list = jsonDecode(data);
    return list.map((e) => Recipe.fromJson(e)).toList();
  }

  Future<List<Recipe>> getRecipesForBook(String bookId) async {
    final recipes = await getRecipes();
    return recipes.where((r) => r.bookId == bookId).toList();
  }

  Future<void> saveRecipes(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(recipes.map((e) => e.toJson()).toList());
    await prefs.setString(_recipesKey, data);
  }

  Future<void> saveRecipe(Recipe recipe) async {
    final recipes = await getRecipes();
    final index = recipes.indexWhere((r) => r.id == recipe.id);
    if (index >= 0) {
      recipes[index] = recipe;
    } else {
      recipes.add(recipe);
    }
    await saveRecipes(recipes);
  }

  Future<void> deleteRecipe(String recipeId) async {
    final recipes = await getRecipes();
    recipes.removeWhere((r) => r.id == recipeId);
    await saveRecipes(recipes);
  }
}
