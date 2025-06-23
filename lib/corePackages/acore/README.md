# ![acore flutter logo](https://github.com/user-attachments/assets/4d9e5a56-d4e2-42a8-97e7-a584409f4529) `acore-flutter` [![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?&logo=buy-me-a-coffee&logoColor=black)](https://ahmetcetinkaya.me/donate)

This repository provides a comprehensive core package written in Dart, containing reusable implementations, abstractions, and helper code snippets for Flutter applications. It aims to offer optimized, modular, and maintainable solutions for common needs in Flutter development.

## 💻 Technologies Used

This project is built using the following technologies:

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)

### Minimal Package Usage

This package minimizes the use of external dependencies. Most implementations are written using Dart and Flutter core libraries to ensure better control, performance, and maintainability.

### Flutter-Specific Implementations

`acore-flutter` contains Flutter-specific components, utilities, and abstractions, providing reusable and optimized solutions tailored for Flutter applications.

## 📦 What’s Included?

- **UI Components**: Reusable widgets such as `DateTimePickerField`, `NumericInput`, and more under `src/components`.
- **Dependency Injection**: Simple and extensible DI container and abstractions (`src/dependency_injection`).
- **Error Handling**: Business exception and error abstractions (`src/errors`).
- **File Utilities**: File abstractions and helpers (`src/file`).
- **Logging**: Console logger, log levels, and logging abstractions (`src/logging`).
- **Mapping**: Core mappers and abstractions for data transformation (`src/mapper`).
- **Query Utilities**: Query models and helpers (`src/queries`).
- **Repository Pattern**: Repository abstractions and models (`src/repository`).
- **Sound Utilities**: Sound abstractions and helpers (`src/sounds`).
- **Storage**: Storage abstractions and helpers (`src/storage`).
- **Time & Date Utilities**: Date formatting, helpers, and week day utilities (`src/time`).
- **General Utilities**: Collection, color, and other helpers (`src/utils`).

## ⚡ Getting Started

This section explains how to get your project up and running.

### 📋 Requirements

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.5.3)

### 🛠️ Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/ahmet-cetinkaya/acore-flutter.git
   ```
2. Navigate into the project directory:
   ```bash
   cd acore-flutter
   ```
3. Get the dependencies:
   ```bash
   flutter pub get
   ```

## 📦 Adding as a Submodule

To add this repository as a submodule to another project, follow these steps:

1. Navigate to your project directory:
   ```bash
   cd your-project-directory
   ```
2. Add the submodule:
   ```bash
   git submodule add https://github.com/ahmet-cetinkaya/acore-flutter.git path/to/submodule
   ```
3. Initialize and update the submodule:
   ```bash
   git submodule update --init --recursive
   ```
4. Navigate into the submodule directory and get dependencies:
   ```bash
   cd path/to/submodule
   flutter pub get
   ```

## 🤝 Contributing

If you'd like to contribute, please follow these steps:

1. Fork the repository
2. Create a new branch (`git checkout -b feat/feature-branch`)
3. Make your changes
4. Commit your changes (`git commit -m 'feat: add new feature'`)
5. Push to the branch (`git push origin feat/feature-branch`)
6. Open a Pull Request
