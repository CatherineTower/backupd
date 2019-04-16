module BackupFile;

private import std.stdio;
private import std.datetime;
private import std.array : split;
private import std.format : format;
private import std.file;
private import std.conv : to;
private import std.path;

class BackupFile {
public:

  struct FileEntry {
    SysTime modTime;
    int type;
    enum Type {file, directory};
  }

  this() { }

  this(string filename) {
    this.readFile(filename);
  }

  void readFile(string filename) {
    auto file = File(filename, "r");
    scope(exit) {
      file.close();
    }

    auto lines = file.byLine();
    foreach(line; lines) {
      auto tmp = split(line, '%');

      FileEntry entry;
      switch(tmp[0]) {
      case "d":
        entry.type = FileEntry.Type.directory;
        break;
      case "f":
        entry.type = FileEntry.Type.file;
        break;
      default:
        assert(0, "Unknown type");
      }

      entry.modTime = SysTime(to!ulong(tmp[2]));
      entries[to!string(tmp[1])] = entry;
    }
  }

  void writeFile(string filename) const {
    auto file = new File(filename, "w");
    scope(exit) {
      file.close();
    }
    foreach(entry; entries.byKeyValue) {

      char fileType;
      switch(entry.value.type) {
      case FileEntry.Type.file:
        fileType = 'f';
        break;
      case FileEntry.Type.directory:
        fileType = 'd';
        break;
      default:
        assert(0, "Unknown type");
      }
      /* This is type%path%timestamp, but that doesn't come across
         very well */
      file.write(format("%s%%%s%%%s\n", fileType, entry.key,
                        entry.value.modTime.stdTime));
    }
  }

  void generateEntries(string rootDir) {
    auto dir = dirEntries(rootDir, SpanMode.breadth);
    foreach(file; dir) {

      FileEntry tmp;
      tmp.modTime = file.timeLastModified;

      if(file.isFile) {
        tmp.type = FileEntry.Type.file;
      } else if (file.isDir) {
        tmp.type = FileEntry.Type.directory;
      } else {
        assert(0, "Unsupported file");
      }

      entries[file.name] = tmp;
    }
  }

private:
  FileEntry[string] entries;
}

unittest {
  string path = "~/src";
  path = path.expandTilde.absolutePath;
  auto tmp = new BackupFile;
  try {
    tmp.generateEntries(path);
    tmp.writeFile("testFile");

    auto tmp1 = new BackupFile("testFile");
    tmp1.writeFile("outFile");
  } catch(FileException e) {
    writeln(e.msg);
  } catch(Exception e) {
    writeln(e.msg, e.line);
  }
}
