# 🍳 Pimenton

A modern **Flutter** application built with **Material 3** for managing, organizing, importing, and sharing your favorite food recipes. Organize recipes into custom cookbooks, import recipes directly from websites or social media links, load existing `.json` and `.paprika` recipe files, and share your culinary collections effortlessly.

---

## ✨ Features

- **📚 Multiple Recipe Books**: Create, customize, and manage distinct cookbooks (e.g., *Favorites*, *Italian*, *Desserts*).
- **✍️ Manual Recipe Creation & Editing**: Build rich recipe entries with prep time, cook time, servings, step-by-step instructions, ingredients list, and custom hero images.
- **🌐 Web Page Import (In-App Browser)**: Navigate to any recipe website using an in-app WebView and extract recipes automatically using Schema.org `JSON-LD` parser.
- **🔗 Social Link Extraction**: Paste direct links from Instagram, TikTok, Facebook, or food blogs to automatically scrape title, image, and description meta-data.
- **📁 File Import Support**: Import recipes from `.json` files or `.paprikarecipes` / `.paprikarecipe` archives (gzipped JSON / ZIP).
- **📤 Easy Sharing**: Export individual recipes or entire cookbooks as JSON files using the native system share dialog.
- **🎨 Material 3 UI**: Clean, responsive layout featuring Material 3 color roles, dynamic theming (Dark & Light mode support), floating action buttons, and modal bottom sheets.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.0.0`)
- Dart SDK (`>= 3.0.0 < 4.0.0`)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/pimenton.git
   cd pimenton
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   # On Android / iOS / Desktop
   flutter run
   ```

---

## 📦 Supported File Formats for Import

| Format | Extension | Description |
| :--- | :--- | :--- |
| **JSON** | `.json` | Single recipe JSON object or array of recipe objects |
| **Paprika Archive** | `.paprikarecipes` / `.zip` | Zip archive containing gzipped JSON files |
| **Paprika Recipe** | `.paprikarecipe` | Single gzipped JSON recipe file |

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
