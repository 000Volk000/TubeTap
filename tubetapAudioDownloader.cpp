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
  command += "-o \"" + output_path + "%" + "(title)s.%" + "(ext)s\" ";

  // Append 'K' to the bitrate for CBR and set audio format to mp3
  command += "--extract-audio --audio-format mp3 ";
  command += "--audio-quality " + format + "K \"" + url + "\"";

  FILE *pipe = popen(command.c_str(), "r");
  if (!pipe)
  {
    cerr << "Error al iniciar la descarga" << endl;
    return EXIT_FAILURE;
  }

  char buffer[256];
  string filename;
  string full_path;
  string final_path; // Use a separate variable for the final path from extractor
  regex title_regex(R"(\s*\[download\]\s+Destination:\s+(.*))");
  regex download_regex(R"(\s*\[download\]\s+(.+)\s+has already been downloaded)");
  regex extract_regex(R"(\s*\[ExtractAudio\]\s+Destination:\s+(.*))");

  while (fgets(buffer, sizeof(buffer), pipe) != nullptr)
  {
    string line(buffer);
    smatch match;

    // Check for the final extracted file path first, as it's the most reliable
    if (regex_search(line, match, extract_regex))
    {
      final_path = match[1].str();
      filename = fs::path(final_path).filename().string();
    }
    // Fallback to other regexes if the extract line isn't found
    else if (regex_search(line, match, title_regex))
    {
      full_path = match[1].str();
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
  }

  int status = pclose(pipe);
  if (status == 0)
  {
    // Use the final path from the extractor if it exists, otherwise use the downloaded path
    if (!final_path.empty()) {
        full_path = final_path;
    }

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
            // Only look for the final mp3 file
            if (ext == ".mp3")
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