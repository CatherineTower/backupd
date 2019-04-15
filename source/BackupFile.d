module BackupFile;

private import std.stdio;
private import std.datetime;
private import std.array : split;
private import std.format : format;
private import std.file;
private import std.conv : to;

class BackupFile {
public:

  this() { }

  this(string filename) {
    this.readFile(filename);
  }

  void readFile(string filename) {
    auto file = File(filename, "r");
    auto lines = file.byLine();
    foreach(line; lines) {
      auto tmp = split(line, '%');
      entries[to!string(tmp[0])] = SysTime(to!ulong(tmp[1]));
    }
    file.close();
  }

  void writeFile(string filename) {
    auto file = new File(filename, "w");
    foreach(entry; entries.byKeyValue) {
      file.write(format("%s%%%s\n", entry.key, entry.value.stdTime));
    }
    file.close();
  }

  void generateEntries(string rootDir) {
    auto dir = dirEntries(rootDir, SpanMode.breadth);
    foreach(file; dir) {
      entries[file.name] = file.timeLastAccessed;
    }
  }

private:
  SysTime[string] entries;
}

unittest {
  auto tmp = new BackupFile;
  tmp.generateEntries("./test");
  tmp.writeFile("testFile");

  auto tmp1 = new BackupFile("testFile");
  tmp1.writeFile("outFile");
}
