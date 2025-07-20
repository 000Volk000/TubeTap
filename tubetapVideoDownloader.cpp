// g++ -std=c++17 -o tubetapVideoDownloader tubetapVideoDownloader.cpp -lstdc++fs

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

const string DOWNLOAD_BASE = "/tmp/";

void createDirectories()
{
  fs::create_directories(DOWNLOAD_BASE + "Videos");
}

int downloadMedia(const string &url, const string &format,
                  const string &type)
{
  string output_path = DOWNLOAD_BASE + "Videos/";
  string command = "yt-dlp --no-warnings --newline ";
  command += "-o \"" + output_path + "%(title)s.%(ext)s\" ";

  command += "-f \"bestvideo[ext=mp4][height<=" + format +
             "]+bestaudio[ext=m4a]/best[ext=mp4]/best\" \"" + url + "\"";

  FILE *pipe = popen(command.c_str(), "r");
  if (!pipe)
  {
    cerr << "Error al iniciar la descarga" << endl;
    return EXIT_FAILURE;
  }

  char buffer[256];
  string filename;
  regex title_regex(R"(Destination:\s+(.*\.(mp3|mp4)))");

  while (fgets(buffer, sizeof(buffer), pipe) != nullptr)
  {
    string line(buffer);
    smatch match;

    if (regex_search(line, match, title_regex))
    {
      filename = fs::path(match[1].str()).filename().string();
    }
  }

  int status = pclose(pipe);
  if (status == 0)
  {
    cout << "\n\033[32mDescarga completada con éxito\033[0m\n\n";
    return (EXIT_SUCCESS);
  }
  else
  {
    cout << "\n\033[31mError en la descarga\033[0m\n\n";
    return (EXIT_FAILURE);
  }
}

int main(int argc, char const *argv[])
{
  createDirectories();

  if (argc != 3)
  {
    cout << "Bad Arguments\n";
    cout << "Arguments sould be:\n";
    cout << argv[0] << "<Youtube Link> <Resolution (144, 240, 360, 480, 720, 1080)>\n";
    return -1;
  }

  int ret = downloadMedia(argv[1], argv[2], "mp4");

  return ret;
}
