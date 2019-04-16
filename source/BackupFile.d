private import std.stdio;
private import std.datetime;
private import std.array : split;
private import std.file;
private import std.conv : to;
private import std.path;
private import std.exception : collectException;

class BackupFile {
public:
  /* The file list will be stored in the output directory under this
     name */
  static string backupFileListName = ".backupfilelist";

  struct FileEntry {
    SysTime modTime;
    enum Type {file, directory};
    Type type;

    this(SysTime modTime, FileEntry.Type type) {
      this.modTime = modTime;
      this.type = type;
    }

    bool isFile() const @property {
      return type == Type.file;
    }

    bool isDir() const @property {
      return type == Type.directory;
    }
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
      /* This is type % path % timestamp, but that doesn't come across
         very well */
      file.writef("%s%%%s%%%s\n", fileType, entry.key,
                  entry.value.modTime.stdTime);
    }
  }

  void generateEntries(string rootDir) {
    auto dir = dirEntries(rootDir, SpanMode.breadth);
    foreach(file; dir) {

      FileEntry tmp;
      auto e = collectException(tmp.modTime = file.timeLastModified);
      if(e) {
        stderr.writeln(e.msg);
        continue;
      }

      if(file.isFile) {
        tmp.type = FileEntry.Type.file;
      } else if (file.isDir) {
        tmp.type = FileEntry.Type.directory;
      } else {
        assert(0, "Unsupported file: " ~ file.name);
      }

      entries[file.name] = tmp;
    }
  }

  auto getEntries() const {
    return entries.byKeyValue;
  }

  auto opBinaryRight(string op)(string query)
    if(op == "in") {
      return query in entries;
    }


private:
  FileEntry[string] entries;
}

unittest {
  string path = "/usr/include";
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
