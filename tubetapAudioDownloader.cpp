// g++ -std=c++17 -o tubetapAudioDownloader tubetapAudioDownloader.cpp -lstdc++fs

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
  fs::create_directories(DOWNLOAD_BASE + "Audios");
}

int downloadMedia(const string &url, const string &format,
                  const string &type)
{
  string output_path = DOWNLOAD_BASE + "Audios/";
  string command = "yt-dlp --no-warnings --newline ";
  command += "-o \"" + output_path + "%(title)s.%(ext)s\" ";

  command += "--extract-audio --audio-format mp3 ";
  command += "--audio-quality " + format + " \"" + url + "\"";

  FILE *pipe = popen(command.c_str(), "r");
  if (!pipe)
  {
    cerr << "Error al iniciar la descarga" << endl;
    return EXIT_FAILURE;
  }

  char buffer[256];
  string filename;
  string full_path;
  regex title_regex(R"(\[download\]\s+Destination:\s+(.*))");
  regex download_regex(R"(\[download\]\s+(.+)\s+has already been downloaded)");
  regex merge_regex(R"(\[Merger\]\s+Merging formats into\s+\"(.+)\")");

  while (fgets(buffer, sizeof(buffer), pipe) != nullptr)
  {
    string line(buffer);
    smatch match;

    // Try different regex patterns to catch the file path
    if (regex_search(line, match, title_regex))
    {
      full_path = match[1].str();
      // Remove quotes if present
      if (full_path.front() == '"' && full_path.back() == '"')
      {
        full_path = full_path.substr(1, full_path.length() - 2);
      }
      filename = fs::path(full_path).filename().string();
    }
    else if (regex_search(line, match, download_regex))
    {
      full_path = match[1].str();
      if (full_path.front() == '"' && full_path.back() == '"')
      {
        full_path = full_path.substr(1, full_path.length() - 2);
      }
      filename = fs::path(full_path).filename().string();
    }
    else if (regex_search(line, match, merge_regex))
    {
      full_path = match[1].str();
      filename = fs::path(full_path).filename().string();
    }
  }

  int status = pclose(pipe);
  if (status == 0)
  {
    // If we couldn't parse the path from output, search for the most recent file
    if (full_path.empty())
    {
      string search_dir = DOWNLOAD_BASE + "Audios/";
      try
      {
        auto current_time = fs::file_time_type::clock::now();
        fs::file_time_type newest_time = fs::file_time_type::min();

        for (const auto &entry : fs::directory_iterator(search_dir))
        {
          if (entry.is_regular_file())
          {
            string ext = entry.path().extension().string();
            if (ext == ".mp3" || ext == ".m4a")
            {
              auto file_time = fs::last_write_time(entry);
              if (file_time > newest_time)
              {
                newest_time = file_time;
                full_path = entry.path().string();
              }
            }
          }
        }
      }
      catch (const exception &e)
      {
        cerr << "Error searching for files: " << e.what() << endl;
      }
    }

    // Output the full path to stdout for the Python script to capture
    cout << "DOWNLOADED_FILE:" << full_path << endl;
    return EXIT_SUCCESS;
  }
  else
  {
    cerr << "Error en la descarga" << endl;
    return EXIT_FAILURE;
  }
}

int main(int argc, char const *argv[])
{
  createDirectories();

  if (argc != 3)
  {
    cout << "Bad Arguments\n";
    cout << "Arguments sould be:\n";
    cout << argv[0] << "<Youtube Link> <Bitrate (128, 192, 256, 320)>\n";
    return -1;
  }

  int ret = downloadMedia(argv[1], argv[2], "mp3");

  return ret;
}
