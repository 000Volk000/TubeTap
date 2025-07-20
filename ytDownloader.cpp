// g++ -std=c++17 -o ytDownloader ytDownloader.cpp -lstdc++fs

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <regex>
#include <string>
#include <sys/stat.h>
#include <vector>

using namespace std;
namespace fs = filesystem;

const string DOWNLOAD_BASE =
    string(getenv("HOME")) + "/Downloads/yt_Downloader/";

void clearScreen() { system("clear"); }

void createDirectories() {
  fs::create_directories(DOWNLOAD_BASE + "Audios");
  fs::create_directories(DOWNLOAD_BASE + "Videos");
}

void showProgress(const string &filename, const string &line) {
  regex progress_regex(
      R"(\[download\]\s+([\d.]+)%.*?\s+([\d.]+\wB/s)?\s+ETA\s+([\d:]+))");

  smatch match;
  if (regex_search(line, match, progress_regex)) {
    string progress = match[1];
    string speed = match[2].str().empty() ? "??MB/s" : match[2].str();
    string eta = match[3];

    cout << "\r\033[K"; // Limpiar línea
    cout << "Descargando: " << filename.substr(0, 40) << " " << progress
         << "% [" << string(stoi(progress) / 2, '=') << ">] "
         << "[" << eta << "] @ " << speed << flush;
  }
}

void downloadMedia(const string &url, const string &format,
                   const string &type) {
  string output_path = DOWNLOAD_BASE + (type == "mp3" ? "Audios/" : "Videos/");
  string command = "yt-dlp --no-warnings --newline ";
  command += "-o \"" + output_path + "%(title)s.%(ext)s\" ";

  if (type == "mp3") {
    command += "--extract-audio --audio-format mp3 ";
    command += "--audio-quality " + format + " \"" + url + "\"";
  } else {
    command += "-f \"bestvideo[ext=mp4][height<=" + format +
               "]+bestaudio[ext=m4a]/best[ext=mp4]/best\" \"" + url + "\"";
  }

  FILE *pipe = popen(command.c_str(), "r");
  if (!pipe) {
    cerr << "Error al iniciar la descarga" << endl;
    return;
  }

  char buffer[256];
  string filename;
  regex title_regex(R"(Destination:\s+(.*\.(mp3|mp4)))");

  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    string line(buffer);
    smatch match;

    if (regex_search(line, match, title_regex)) {
      filename = fs::path(match[1].str()).filename().string();
    }
    showProgress(filename, line);
  }

  int status = pclose(pipe);
  if (status == 0) {
    cout << "\n\033[32mDescarga completada con éxito\033[0m\n\n";
  } else {
    cout << "\n\033[31mError en la descarga\033[0m\n\n";
  }
}

void processPlaylist(const string &playlist_url) {
  string temp_file = DOWNLOAD_BASE + "temp_playlist.txt";
  string command = "yt-dlp --flat-playlist --get-url \"" + playlist_url +
                   "\" > " + temp_file;
  system(command.c_str());

  ifstream file(temp_file);
  vector<string> urls;
  string line;

  while (getline(file, line)) {
    urls.push_back(line);
  }
  file.close();

  cout << "1. Video (.mp4)\n2. Audio (.mp3)\nOpción (1/2): ";
  int media_type;
  cin >> media_type;

  if (media_type == 1) {
    cout << "Resoluciones disponibles: 144, 240, 360, 480, 720, "
            "1080\nSeleccione resolución: ";
    string res;
    cin >> res;

    for (const auto &url : urls) {
      downloadMedia(url, res, "mp4");
    }
  } else {
    cout << "Calidades disponibles: 128K, 192K, 256K, 320K\nSeleccione "
            "calidad: ";
    string quality;
    cin >> quality;

    for (const auto &url : urls) {
      downloadMedia(url, quality.substr(0, 3), "mp3");
    }
  }

  fs::remove(temp_file);
}

void singleDownload(const string &url) {
  cout << "1. Video (.mp4)\n2. Audio (.mp3)\nOpción (1/2): ";
  int media_type;
  cin >> media_type;

  if (media_type == 1) {
    cout << "Formatos disponibles:\n"
         << "1. 144p\n2. 240p\n3. 360p\n4. 480p\n5. 720p\n"
         << "Seleccione calidad: ";
    int res;
    cin >> res;
    vector<string> resolutions = {"144", "240", "360", "480", "720"};
    downloadMedia(url, resolutions[res - 1], "mp4");
  } else {
    cout << "Formatos disponibles:\n"
         << "1. 128K (calidad estándar)\n"
         << "2. 192K (calidad buena)\n"
         << "3. 256K (calidad alta)\n"
         << "4. 320K (calidad premium)\n"
         << "Seleccione calidad: ";
    int qual;
    cin >> qual;
    vector<string> qualities = {"128K", "192K", "256K", "320K"};
    downloadMedia(url, qualities[qual - 1].substr(0, 3), "mp3");
  }
}

int main() {
  createDirectories();
  clearScreen();

  cout << "Elige entre playlist o enlace/archivo.txt:\n"
       << "1. Playlist\n"
       << "2. Enlace/Archivo.txt\n"
       << "Opción (1/2): ";

  int option;
  cin >> option;
  cin.ignore();

  if (option == 1) {
    cout << "Introduce el enlace a la playlist: ";
    string playlist_url;
    getline(cin, playlist_url);
    processPlaylist(playlist_url);
  } else {
    cout << "Introduce el enlace o el archivo .txt: ";
    string input;
    getline(cin, input);

    if (input.find(".txt") != string::npos) {
      ifstream file(input);
      vector<string> urls;
      string line;

      while (getline(file, line)) {
        urls.push_back(line);
      }
      file.close();

      cout << "1. Video (.mp4)\n2. Audio (.mp3)\nOpción (1/2): ";
      int media_type;
      cin >> media_type;

      if (media_type == 1) {
        cout << "Resoluciones disponibles: 144, 240, 360, 480, 720, "
                "1080\nSeleccione resolución: ";
        string res;
        cin >> res;

        for (const auto &url : urls) {
          downloadMedia(url, res, "mp4");
        }
      } else {
        cout << "Calidades disponibles: 128K, 192K, 256K, 320K\nSeleccione "
                "calidad: ";
        string quality;
        cin >> quality;

        for (const auto &url : urls) {
          downloadMedia(url, quality.substr(0, 3), "mp3");
        }
      }
    } else {
      singleDownload(input);
    }
  }

  return 0;
}
